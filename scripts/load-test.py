#!/usr/bin/env python3
"""
Нагрузочный тест для поиска.
"""

import asyncio
import aiohttp
import time
import argparse
import random
import json
from typing import List, Dict
from collections import defaultdict

# Набор тестовых запросов
SEARCH_QUERIES = [
    "тест", "документ", "поиск", "индекс", "данные",
    "система", "архитектура", "микросервис", "база",
    "производительность", "масштабирование", "нагрузка"
]

DOCUMENT_TITLES = [
    "Тестовый документ", "Пример данных", "Руководство по архитектуре",
    "Настройка производительности", "Практики масштабирования",
    "Шаблоны микросервисов", "Проектирование баз данных"
]

class LoadTester:
    def __init__(self, base_url: str, requests: int, concurrency: int):
        self.base_url = base_url
        self.total_requests = requests
        self.concurrency = concurrency
        self.results = defaultdict(list)
        self.errors = []
        
    async def search_request(self, session: aiohttp.ClientSession, query: str):
        """Выполнение поискового запроса."""
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
            self.errors.append(f"Ошибка поиска: {str(e)}")
            return False
    
    async def document_request(self, session: aiohttp.ClientSession, token: str = None):
        """Создание документа."""
        start = time.time()
        try:
            headers = {}
            if token:
                headers['Authorization'] = f'Bearer {token}'
            
            title = random.choice(DOCUMENT_TITLES)
            content = f"Тестовое содержимое для нагрузочного сценария: {random.randint(1000, 9999)}"
            
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
            self.errors.append(f"Ошибка создания документа: {str(e)}")
            return False
    
    async def worker(self, worker_id: int):
        """Запуск воркера нагрузки."""
        async with aiohttp.ClientSession() as session:
            requests_per_worker = self.total_requests // self.concurrency
            
            for i in range(requests_per_worker):
                # 80% запросов на поиск и 20% на создание
                if random.random() < 0.8:
                    query = random.choice(SEARCH_QUERIES)
                    await self.search_request(session, query)
                else:
                    await self.document_request(session)
                
                # Добавление паузы для реалистичной нагрузки
                await asyncio.sleep(random.uniform(0.01, 0.1))
    
    async def run(self):
        """Запуск теста."""
        print(f"\n{'='*60}")
        print(f"Нагрузочное тестирование: {self.base_url}")
        print(f"Всего запросов: {self.total_requests}")
        print(f"Параллелизм: {self.concurrency}")
        print(f"{'='*60}\n")
        
        start_time = time.time()
        
        # Запуск воркеров
        tasks = [self.worker(i) for i in range(self.concurrency)]
        await asyncio.gather(*tasks)
        
        total_time = time.time() - start_time
        
        # Анализ результатов
        self.print_results(total_time)
    
    def print_results(self, total_time: float):
        """Вывод результатов."""
        print(f"\n{'='*60}")
        print("Результаты")
        print(f"{'='*60}\n")
        
        total_requests = sum(len(results) for results in self.results.values())
        
        print(f"Общее время: {total_time:.2f} c")
        print(f"Всего запросов: {total_requests}")
        print(f"Запросов в секунду: {total_requests / total_time:.2f}")
        print(f"Ошибок: {len(self.errors)}")
        print(f"Доля ошибок: {len(self.errors) / total_requests * 100:.2f}%")
        print()
        
        # Расчет статистики по типам запросов
        for req_type, results in self.results.items():
            if not results:
                continue
            
            durations = [r['duration'] for r in results]
            durations.sort()
            
            print(f"\n{req_type.upper()} запросы:")
            print(f"  Количество: {len(results)}")
            print(f"  Минимум: {min(durations)*1000:.2f} мс")
            print(f"  Максимум: {max(durations)*1000:.2f} мс")
            print(f"  Среднее: {sum(durations)/len(durations)*1000:.2f} мс")
            print(f"  P50: {durations[int(len(durations)*0.5)]*1000:.2f} мс")
            print(f"  P95: {durations[int(len(durations)*0.95)]*1000:.2f} мс")
            print(f"  P99: {durations[int(len(durations)*0.99)]*1000:.2f} мс")
            
            # Расчет статистики кеша
            if req_type == 'search':
                cache_hits = sum(1 for r in results if r.get('cache') == 'HIT')
                cache_misses = sum(1 for r in results if r.get('cache') == 'MISS')
                hit_rate = cache_hits / (cache_hits + cache_misses) * 100 if (cache_hits + cache_misses) > 0 else 0
                print(f"  Доля попаданий кеша: {hit_rate:.2f}% ({cache_hits} попаданий, {cache_misses} промахов)")
        
        # Вывод ошибок
        if self.errors:
            print(f"\n\nОшибки (первые 10):")
            for error in self.errors[:10]:
                print(f"  - {error}")
        
        print(f"\n{'='*60}\n")

def main():
    parser = argparse.ArgumentParser(description="Нагрузочный тест для поисковой системы")
    parser.add_argument("--url", default="http://localhost", help="Базовый URL (по умолчанию: http://localhost)")
    parser.add_argument("--requests", type=int, default=1000, help="Количество запросов (по умолчанию: 1000)")
    parser.add_argument("--concurrency", type=int, default=10, help="Число параллельных воркеров (по умолчанию: 10)")
    
    args = parser.parse_args()
    
    tester = LoadTester(args.url, args.requests, args.concurrency)
    asyncio.run(tester.run())

if __name__ == "__main__":
    main()
