"""
Run this ONCE locally before deploying to Render.
Scrapes notes for all topics and caches them in Firestore.
After this, the deployed app reads from cache — no scraping on the server.

Usage:
    cd backend
    python seed_all_notes.py
"""
import requests
import time

BASE_URL = "http://localhost:8000"

TOPICS = [
    # DSA
    (101, "Arrays & Strings", "DSA"),
    (102, "Linked Lists", "DSA"),
    (103, "Stacks & Queues", "DSA"),
    (104, "Trees & Binary Trees", "DSA"),
    (105, "Graphs", "DSA"),
    (106, "Sorting Algorithms", "DSA"),
    (107, "Dynamic Programming", "DSA"),
    (108, "Hashing", "DSA"),
    (109, "Recursion & Backtracking", "DSA"),
    (110, "Heaps & Priority Queues", "DSA"),
    (111, "Tries", "DSA"),
    (112, "Greedy Algorithms", "DSA"),
    # DBMS
    (201, "Introduction to DBMS", "DBMS"),
    (202, "ER Model", "DBMS"),
    (203, "Relational Model", "DBMS"),
    (204, "SQL Basics", "DBMS"),
    (205, "Advanced SQL", "DBMS"),
    (206, "Normalization", "DBMS"),
    (207, "Transactions & ACID", "DBMS"),
    (208, "Indexing & Hashing", "DBMS"),
    (209, "Concurrency Control", "DBMS"),
    (210, "NoSQL Databases", "DBMS"),
    # OS
    (301, "Introduction to OS", "Operating Systems"),
    (302, "Process Management", "Operating Systems"),
    (303, "CPU Scheduling", "Operating Systems"),
    (304, "Threads & Concurrency", "Operating Systems"),
    (305, "Process Synchronization", "Operating Systems"),
    (306, "Deadlocks", "Operating Systems"),
    (307, "Memory Management", "Operating Systems"),
    (308, "Virtual Memory", "Operating Systems"),
    (309, "File Systems", "Operating Systems"),
    (310, "I/O Systems", "Operating Systems"),
    # CN
    (401, "Network Fundamentals", "Computer Networks"),
    (402, "OSI Model", "Computer Networks"),
    (403, "TCP/IP Model", "Computer Networks"),
    (404, "IP Addressing & Subnetting", "Computer Networks"),
    (405, "Routing Protocols", "Computer Networks"),
    (406, "TCP & UDP", "Computer Networks"),
    (407, "Application Layer Protocols", "Computer Networks"),
    (408, "Network Security", "Computer Networks"),
    (409, "Wireless Networks", "Computer Networks"),
    (410, "Socket Programming", "Computer Networks"),
    # Python
    (501, "Python Basics", "Python"),
    (502, "Control Flow", "Python"),
    (503, "Functions", "Python"),
    (504, "OOP in Python", "Python"),
    (505, "File Handling", "Python"),
    (506, "Exception Handling", "Python"),
    (507, "Modules & Packages", "Python"),
    (508, "List Comprehensions", "Python"),
    (509, "Decorators & Generators", "Python"),
    (510, "NumPy & Pandas", "Python"),
    # Java
    (601, "Java Basics", "Java"),
    (602, "OOP in Java", "Java"),
    (603, "Inheritance & Polymorphism", "Java"),
    (604, "Interfaces & Abstract Classes", "Java"),
    (605, "Exception Handling in Java", "Java"),
    (606, "Collections Framework", "Java"),
    (607, "Multithreading", "Java"),
    (608, "Java I/O", "Java"),
    (609, "Generics", "Java"),
    (610, "Java 8 Features", "Java"),
]

def seed_topic(topic_id, title, subject):
    try:
        resp = requests.post(
            f"{BASE_URL}/api/notes/fetch",
            json={"topic_title": title, "subject": subject},
            timeout=40,
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("success"):
                content_len = len(data.get("content", ""))
                print(f"  ✓ {title} ({content_len} chars)")
                return True
            else:
                print(f"  ✗ {title} — {data.get('message', 'no content')}")
        else:
            print(f"  ✗ {title} — HTTP {resp.status_code}")
    except Exception as e:
        print(f"  ✗ {title} — {e}")
    return False

if __name__ == "__main__":
    print(f"Seeding notes for {len(TOPICS)} topics...\n")
    ok = 0
    fail = 0
    for topic_id, title, subject in TOPICS:
        success = seed_topic(topic_id, title, subject)
        if success:
            ok += 1
        else:
            fail += 1
        time.sleep(1.5)  # be polite to GFG

    print(f"\nDone — {ok} succeeded, {fail} failed")
    if fail > 0:
        print("Failed topics will use Wikipedia fallback or show empty notes.")
        print("You can retry failed ones individually from the Admin Panel.")
