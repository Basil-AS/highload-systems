#!/usr/bin/env python3
"""
Нагрузочное тестирование поисковой системы
ЛР4: Высоконагруженные системы
"""

import asyncio
import aiohttp
import time
import argparse
import random
import json
from typing import List, Dict
from collections import defaultdict

# Тестовые запросы
SEARCH_QUERIES = [
    "test", "document", "search", "index", "data",
    "system", "architecture", "microservice", "database",
    "performance", "scalability", "high load"
]

DOCUMENT_TITLES = [
    "Test Document", "Sample Data", "Architecture Guide",
    "Performance Tuning", "Scalability Best Practices",
    "Microservices Patterns", "Database Design"
]

class LoadTester:
    def __init__(self, base_url: str, requests: int, concurrency: int):
        self.base_url = base_url
        self.total_requests = requests
        self.concurrency = concurrency
        self.results = defaultdict(list)
        self.errors = []
        
    async def search_request(self, session: aiohttp.ClientSession, query: str):
        """Выполнить поисковый запрос"""
        start = time.time()
        try:
            async with session.get(
                f"{self.base_url}/api/search",
                params={"q": query, "limit": 10},
                timeout=aiohttp.ClientTimeout(total=10)
            ) as response:
                await response.json()
                duration = time.time() - start
                self.results['search'].append({
                    'duration': duration,
                    'status': response.status,
                    'cache': response.headers.get('X-Cache-Status', 'MISS')
                })
                return True
        except Exception as e:
            self.errors.append(f"Search error: {str(e)}")
            return False
    
    async def document_request(self, session: aiohttp.ClientSession, token: str = None):
        """Создать документ"""
        start = time.time()
        try:
            headers = {}
            if token:
                headers['Authorization'] = f'Bearer {token}'
            
            title = random.choice(DOCUMENT_TITLES)
            content = f"Test content for load testing: {random.randint(1000, 9999)}"
            
            async with session.post(
                f"{self.base_url}/api/documents",
                json={"title": title, "content": content},
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=10)
            ) as response:
                await response.json()
                duration = time.time() - start
                self.results['document'].append({
                    'duration': duration,
                    'status': response.status
                })
                return True
        except Exception as e:
            self.errors.append(f"Document error: {str(e)}")
            return False
    
    async def worker(self, worker_id: int):
        """Воркер для генерации нагрузки"""
        async with aiohttp.ClientSession() as session:
            requests_per_worker = self.total_requests // self.concurrency
            
            for i in range(requests_per_worker):
                # 80% поиск, 20% создание документов
                if random.random() < 0.8:
                    query = random.choice(SEARCH_QUERIES)
                    await self.search_request(session, query)
                else:
                    await self.document_request(session)
                
                # Небольшая задержка для более реалистичной нагрузки
                await asyncio.sleep(random.uniform(0.01, 0.1))
    
    async def run(self):
        """Запустить тест"""
        print(f"\n{'='*60}")
        print(f"Load Testing: {self.base_url}")
        print(f"Total Requests: {self.total_requests}")
        print(f"Concurrency: {self.concurrency}")
        print(f"{'='*60}\n")
        
        start_time = time.time()
        
        # Запустить воркеры
        tasks = [self.worker(i) for i in range(self.concurrency)]
        await asyncio.gather(*tasks)
        
        total_time = time.time() - start_time
        
        # Анализ результатов
        self.print_results(total_time)
    
    def print_results(self, total_time: float):
        """Вывести результаты"""
        print(f"\n{'='*60}")
        print("Results")
        print(f"{'='*60}\n")
        
        total_requests = sum(len(results) for results in self.results.values())
        
        print(f"Total Time: {total_time:.2f}s")
        print(f"Total Requests: {total_requests}")
        print(f"Requests/sec: {total_requests / total_time:.2f}")
        print(f"Errors: {len(self.errors)}")
        print(f"Error Rate: {len(self.errors) / total_requests * 100:.2f}%")
        print()
        
        # Статистика по типам запросов
        for req_type, results in self.results.items():
            if not results:
                continue
            
            durations = [r['duration'] for r in results]
            durations.sort()
            
            print(f"\n{req_type.upper()} Requests:")
            print(f"  Count: {len(results)}")
            print(f"  Min: {min(durations)*1000:.2f}ms")
            print(f"  Max: {max(durations)*1000:.2f}ms")
            print(f"  Mean: {sum(durations)/len(durations)*1000:.2f}ms")
            print(f"  P50: {durations[int(len(durations)*0.5)]*1000:.2f}ms")
            print(f"  P95: {durations[int(len(durations)*0.95)]*1000:.2f}ms")
            print(f"  P99: {durations[int(len(durations)*0.99)]*1000:.2f}ms")
            
            # Статистика кэша для поиска
            if req_type == 'search':
                cache_hits = sum(1 for r in results if r.get('cache') == 'HIT')
                cache_misses = sum(1 for r in results if r.get('cache') == 'MISS')
                hit_rate = cache_hits / (cache_hits + cache_misses) * 100 if (cache_hits + cache_misses) > 0 else 0
                print(f"  Cache Hit Rate: {hit_rate:.2f}% ({cache_hits} hits, {cache_misses} misses)")
        
        # Показать ошибки
        if self.errors:
            print(f"\n\nErrors (showing first 10):")
            for error in self.errors[:10]:
                print(f"  - {error}")
        
        print(f"\n{'='*60}\n")

def main():
    parser = argparse.ArgumentParser(description="Load testing для поисковой системы")
    parser.add_argument("--url", default="http://localhost", help="Base URL (default: http://localhost)")
    parser.add_argument("--requests", type=int, default=1000, help="Total requests (default: 1000)")
    parser.add_argument("--concurrency", type=int, default=10, help="Concurrent workers (default: 10)")
    
    args = parser.parse_args()
    
    tester = LoadTester(args.url, args.requests, args.concurrency)
    asyncio.run(tester.run())

if __name__ == "__main__":
    main()
