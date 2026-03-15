"""
scraper_service.py
──────────────────
Full pipeline:
1. Admin types a topic name  →  auto_discover_urls()  finds GFG + TP article URLs
2. Every time a user opens a topic  →  scrape_topic_content() fetches live content
3. Cleaned Markdown is returned to the Flutter app and cached in Firestore
"""

import re
import time
import random
import logging
from dataclasses import dataclass, field
from typing import Optional
from urllib.parse import urlparse, quote_plus
from urllib.robotparser import RobotFileParser

import requests
from bs4 import BeautifulSoup, Tag

logging.basicConfig(level=logging.INFO, format="%(levelname)s │ %(message)s")
log = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────
# DATA CLASSES
# ──────────────────────────────────────────────────────────────

@dataclass
class DiscoveredUrls:
    topic_name: str
    gfg_url: Optional[str] = None
    tp_url: Optional[str] = None

    def has_any(self) -> bool:
        return bool(self.gfg_url or self.tp_url)


@dataclass
class ScrapedContent:
    source: str           # "geeksforgeeks" | "tutorialspoint"
    url: str
    title: str
    cleaned_markdown: str
    scraped_at: str = field(default_factory=lambda: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    success: bool = True
    error: Optional[str] = None


@dataclass
class TopicContent:
    topic_name: str
    gfg: Optional[ScrapedContent] = None
    tp: Optional[ScrapedContent] = None

    def best_content(self) -> str:
        """Return the longest successful content between GFG and TP."""
        candidates = []
        if self.gfg and self.gfg.success and self.gfg.cleaned_markdown:
            candidates.append(self.gfg.cleaned_markdown)
        if self.tp and self.tp.success and self.tp.cleaned_markdown:
            candidates.append(self.tp.cleaned_markdown)
        if not candidates:
            return ""
        return max(candidates, key=len)

    def to_dict(self) -> dict:
        return {
            "topicName": self.topic_name,
            "gfg": _content_to_dict(self.gfg),
            "tp": _content_to_dict(self.tp),
            "cleanedText": self.best_content(),
        }


def _content_to_dict(c: Optional[ScrapedContent]) -> Optional[dict]:
    if c is None:
        return None
    return {
        "source": c.source,
        "url": c.url,
        "title": c.title,
        "cleanedMarkdown": c.cleaned_markdown,
        "scrapedAt": c.scraped_at,
        "success": c.success,
        "error": c.error,
    }


# ──────────────────────────────────────────────────────────────
# HEADERS — rotate to avoid simple bot blocks
# ──────────────────────────────────────────────────────────────

_USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0",
]


def _headers() -> dict:
    return {
        "User-Agent": random.choice(_USER_AGENTS),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Cache-Control": "no-cache",
    }


# ──────────────────────────────────────────────────────────────
# ROBOTS.TXT CHECKER  (cached per domain)
# ──────────────────────────────────────────────────────────────

_robots_cache: dict = {}


def _can_fetch(url: str) -> bool:
    parsed = urlparse(url)
    domain = f"{parsed.scheme}://{parsed.netloc}"
    if domain not in _robots_cache:
        rp = RobotFileParser()
        rp.set_url(f"{domain}/robots.txt")
        try:
            rp.read()
            _robots_cache[domain] = rp
        except Exception:
            return True
    return _robots_cache[domain].can_fetch("*", url)


# ──────────────────────────────────────────────────────────────
# STEP 1 — AUTO-DISCOVER URLS FOR A TOPIC NAME
# ──────────────────────────────────────────────────────────────

class UrlDiscoverer:
    @staticmethod
    def _to_slug(topic: str) -> str:
        return re.sub(r"[^a-z0-9]+", "-", topic.lower()).strip("-")

    def _find_gfg_url(self, topic: str) -> Optional[str]:
        slug = self._to_slug(topic)
        direct_url = f"https://www.geeksforgeeks.org/{slug}/"
        try:
            r = requests.get(direct_url, headers=_headers(), timeout=12, allow_redirects=True)
            if r.status_code == 200 and "geeksforgeeks.org" in r.url:
                soup = BeautifulSoup(r.text, "html.parser")
                if soup.select_one("article") or soup.select_one("div.article-body") or soup.select_one("div.article--viewer"):
                    log.info(f"GFG direct hit: {r.url}")
                    return r.url
        except Exception:
            pass
        return self._search_gfg(topic)

    def _search_gfg(self, topic: str) -> Optional[str]:
        search_url = f"https://www.geeksforgeeks.org/search/{quote_plus(topic)}/"
        try:
            time.sleep(random.uniform(0.5, 1.2))
            r = requests.get(search_url, headers=_headers(), timeout=12)
            soup = BeautifulSoup(r.text, "html.parser")
            for a in soup.select("a[href]"):
                href: str = a.get("href", "")
                if ("geeksforgeeks.org" in href
                        and "/tag/" not in href
                        and "/category/" not in href
                        and "/courses/" not in href
                        and href.count("/") >= 4):
                    log.info(f"GFG search hit: {href}")
                    return href.split("?")[0]
        except Exception as e:
            log.warning(f"GFG search failed: {e}")
        return None

    def _find_tp_url(self, topic: str) -> Optional[str]:
        slug = self._to_slug(topic)
        for url in [
            f"https://www.tutorialspoint.com/{slug}/index.htm",
            f"https://www.tutorialspoint.com/{slug}/{slug}_overview.htm",
            f"https://www.tutorialspoint.com/{slug}.htm",
        ]:
            try:
                r = requests.get(url, headers=_headers(), timeout=12, allow_redirects=True)
                if r.status_code == 200 and "tutorialspoint.com" in r.url:
                    soup = BeautifulSoup(r.text, "html.parser")
                    if soup.select_one("div.tutorialBody") or soup.select_one("div#mainContent"):
                        log.info(f"TP direct hit: {r.url}")
                        return r.url
            except Exception:
                pass
        return self._search_tp(topic)

    def _search_tp(self, topic: str) -> Optional[str]:
        search_url = f"https://www.tutorialspoint.com/search/?q={quote_plus(topic)}"
        try:
            time.sleep(random.uniform(0.5, 1.2))
            r = requests.get(search_url, headers=_headers(), timeout=12)
            soup = BeautifulSoup(r.text, "html.parser")
            for a in soup.select("a.list-group-item, a.sr-result-link, .search-result a"):
                href: str = a.get("href", "")
                if ("tutorialspoint.com" in href
                        and "/search" not in href
                        and (".htm" in href or href.rstrip("/").count("/") >= 3)):
                    log.info(f"TP search hit: {href}")
                    return href
        except Exception as e:
            log.warning(f"TP search failed: {e}")
        return None

    def discover(self, topic_name: str) -> DiscoveredUrls:
        log.info(f"Discovering URLs for: '{topic_name}'")
        result = DiscoveredUrls(topic_name=topic_name)
        result.gfg_url = self._find_gfg_url(topic_name)
        result.tp_url = self._find_tp_url(topic_name)
        return result


# ──────────────────────────────────────────────────────────────
# STEP 2 — SCRAPE CONTENT FROM A URL
# ──────────────────────────────────────────────────────────────

class ContentScraper:
    TIMEOUT = 15

    def scrape_geeksforgeeks(self, url: str) -> ScrapedContent:
        try:
            if not _can_fetch(url):
                raise PermissionError("Blocked by robots.txt")
            time.sleep(random.uniform(0.3, 0.9))
            r = requests.get(url, headers=_headers(), timeout=self.TIMEOUT)
            r.raise_for_status()
            soup = BeautifulSoup(r.text, "html.parser")

            for sel in [
                ".article--recommended", ".article-bottom-text",
                "#GFG_AD_Desktop_InContent", "#GFG_AD_InContent_728x90_1",
                ".adsbygoogle", "nav", "footer", ".article-meta-right",
                ".voting-widget", ".GFG_AD", "[id^='GFG_AD']",
                ".article-page-link-suggestion", ".improvement-suggestion",
                "script", "style", "noscript",
            ]:
                for tag in soup.select(sel):
                    tag.decompose()

            article = (
                soup.select_one("article.content")
                or soup.select_one("div.article-body")
                or soup.select_one("div.article--viewer")
                or soup.select_one("div[class*='text']")
                or soup.select_one("main")
            )
            title = (soup.select_one("h1.article-title, h1, title") or soup.new_tag("span")).get_text(strip=True)

            if not article:
                raise ValueError("Could not find article body")

            md = self._to_markdown(article)
            return ScrapedContent(source="geeksforgeeks", url=url, title=title, cleaned_markdown=md)
        except Exception as e:
            log.error(f"GFG scrape failed ({url}): {e}")
            return ScrapedContent(source="geeksforgeeks", url=url, title="", cleaned_markdown="", success=False, error=str(e))

    def scrape_tutorialspoint(self, url: str) -> ScrapedContent:
        try:
            if not _can_fetch(url):
                raise PermissionError("Blocked by robots.txt")
            time.sleep(random.uniform(0.3, 0.9))
            r = requests.get(url, headers=_headers(), timeout=self.TIMEOUT)
            r.raise_for_status()
            soup = BeautifulSoup(r.text, "html.parser")

            for sel in [
                ".sidebar", "footer", "header", ".tp-rightcol",
                ".related-links", ".prevnext", ".page-nav",
                "script", "style", "noscript", ".tp-ads",
                "#right-column", ".google-ads",
            ]:
                for tag in soup.select(sel):
                    tag.decompose()

            body = (
                soup.select_one("div.tutorialBody")
                or soup.select_one("div#mainContent")
                or soup.select_one("div#page-content")
                or soup.select_one("main")
            )
            title = (soup.select_one("h1, title") or soup.new_tag("span")).get_text(strip=True)

            if not body:
                raise ValueError("Could not find tutorial body")

            md = self._to_markdown(body)
            return ScrapedContent(source="tutorialspoint", url=url, title=title, cleaned_markdown=md)
        except Exception as e:
            log.error(f"TP scrape failed ({url}): {e}")
            return ScrapedContent(source="tutorialspoint", url=url, title="", cleaned_markdown="", success=False, error=str(e))

    def scrape(self, url: str) -> ScrapedContent:
        domain = urlparse(url).netloc
        if "geeksforgeeks.org" in domain:
            return self.scrape_geeksforgeeks(url)
        elif "tutorialspoint.com" in domain:
            return self.scrape_tutorialspoint(url)
        else:
            raise ValueError(f"Unsupported domain: {domain}")

    def _to_markdown(self, container: Tag) -> str:
        lines: list = []
        seen: set = set()

        for el in container.find_all(["h1", "h2", "h3", "h4", "h5",
                                       "p", "pre", "code",
                                       "ul", "ol", "li",
                                       "blockquote", "table"]):
            tag = el.name
            if any(p.name in ("ul", "ol", "pre") for p in el.parents if p != container):
                if tag not in ("ul", "ol", "pre"):
                    continue

            text = el.get_text(separator=" ", strip=True)
            if not text or text in seen:
                continue
            seen.add(text)

            if tag == "h1":
                lines.append(f"\n# {text}\n")
            elif tag == "h2":
                lines.append(f"\n## {text}\n")
            elif tag in ("h3", "h4", "h5"):
                lines.append(f"\n### {text}\n")
            elif tag == "pre":
                code_el = el.find("code")
                lang = ""
                cls_source = code_el or el
                for cls in cls_source.get("class", []):
                    if "language-" in cls:
                        lang = cls.replace("language-", "")
                        break
                    if cls in ("python", "java", "cpp", "c", "javascript", "js", "bash", "sql"):
                        lang = cls
                        break
                raw_code = el.get_text(strip=False)
                lines.append(f"\n```{lang}\n{raw_code.strip()}\n```\n")
            elif tag == "blockquote":
                for line in text.splitlines():
                    lines.append(f"> {line}")
                lines.append("")
            elif tag in ("ul", "ol"):
                items = el.find_all("li", recursive=False)
                for li in items:
                    li_text = li.get_text(separator=" ", strip=True)
                    if li_text:
                        prefix = "-" if tag == "ul" else "1."
                        lines.append(f"{prefix} {li_text}")
                lines.append("")
            elif tag == "p":
                if text:
                    lines.append(f"\n{text}\n")
            elif tag == "table":
                md_table = self._table_to_markdown(el)
                if md_table:
                    lines.append(md_table)

        return self._clean("\n".join(lines))

    def _table_to_markdown(self, table: Tag) -> str:
        rows = table.find_all("tr")
        if not rows:
            return ""
        md_rows = []
        for i, row in enumerate(rows):
            cells = row.find_all(["th", "td"])
            cell_texts = [c.get_text(strip=True).replace("|", "\\|") for c in cells]
            md_rows.append("| " + " | ".join(cell_texts) + " |")
            if i == 0:
                md_rows.append("| " + " | ".join(["---"] * len(cell_texts)) + " |")
        return "\n".join(md_rows) + "\n"

    @staticmethod
    def _clean(text: str) -> str:
        text = re.sub(r"\n{3,}", "\n\n", text)
        for entity, char in {"&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&nbsp;": " "}.items():
            text = text.replace(entity, char)
        text = "\n".join(line.rstrip() for line in text.splitlines())
        return text.strip()


# ──────────────────────────────────────────────────────────────
# STEP 3 — TOP-LEVEL PIPELINE
# ──────────────────────────────────────────────────────────────

class TopicContentPipeline:
    def __init__(self):
        self.discoverer = UrlDiscoverer()
        self.scraper = ContentScraper()

    def discover_urls(self, topic_name: str) -> DiscoveredUrls:
        return self.discoverer.discover(topic_name)

    def fetch_live_content(self, topic_name: str, gfg_url: Optional[str], tp_url: Optional[str]) -> TopicContent:
        import concurrent.futures
        result = TopicContent(topic_name=topic_name)

        def _scrape_gfg():
            return self.scraper.scrape(gfg_url) if gfg_url else None

        def _scrape_tp():
            return self.scraper.scrape(tp_url) if tp_url else None

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
            gfg_future = ex.submit(_scrape_gfg)
            tp_future = ex.submit(_scrape_tp)
            result.gfg = gfg_future.result()
            result.tp = tp_future.result()

        return result


# ──────────────────────────────────────────────────────────────
# STANDALONE TEST  →  python services/scraper_service.py
# ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import json

    TOPIC = "binary search tree"
    print(f"\n{'='*60}")
    print(f"  Testing pipeline for: '{TOPIC}'")
    print(f"{'='*60}\n")

    pl = TopicContentPipeline()

    print("▶ Step 1: Discovering URLs...")
    urls = pl.discover_urls(TOPIC)
    print(f"  GFG : {urls.gfg_url}")
    print(f"  TP  : {urls.tp_url}")

    if not urls.has_any():
        print("\n✗ No URLs found.")
        exit(1)

    print("\n▶ Step 2: Scraping content (live)...")
    content = pl.fetch_live_content(TOPIC, urls.gfg_url, urls.tp_url)

    if content.gfg:
        status = "✓" if content.gfg.success else "✗"
        print(f"\n  {status} GFG  — '{content.gfg.title}'")
        print(f"     Preview: {content.gfg.cleaned_markdown[:300].strip()}...")

    if content.tp:
        status = "✓" if content.tp.success else "✗"
        print(f"\n  {status} TP   — '{content.tp.title}'")
        print(f"     Preview: {content.tp.cleaned_markdown[:300].strip()}...")

    best = content.best_content()
    print(f"\n  Best content length: {len(best)} chars")

    with open("scrape_result.json", "w") as f:
        json.dump(content.to_dict(), f, indent=2)
    print("✓ Full result saved to scrape_result.json")
