import requests
import os
import time
from concurrent.futures import ThreadPoolExecutor
import aiohttp
import asyncio
import uproot


def get_ranges(filename: str, tree_name: str, branch_name: str) -> list((int, int)):
    """
    Returns the (start, stop) position of the baskets in the file.
    """
    with uproot.open(filename) as f:
        tree = f[tree_name]
        branch = tree[branch_name]
        ranges = [
            (basket_seek, basket_seek + basket_bytes)
            for basket_seek, basket_bytes in zip(
                branch.member("fBasketSeek")[: branch._num_normal_baskets],
                branch.member("fBasketBytes")[: branch._num_normal_baskets],
            )
        ]
        assert len(ranges) == branch.num_baskets
        return ranges


script_directory = os.path.dirname(os.path.abspath(__file__))
files_directory = os.path.join(script_directory, "files")


def check_file_availability(filename: str) -> bool:
    # perform a HEAD request to check if the file is available
    response = requests.head(filename)
    return response.status_code == 200


def request_multipart_range(url, ranges, headers=dict()):
    range_string = ",".join([f"{start}-{stop - 1}" for start, stop in ranges])
    headers["Range"] = f"bytes={range_string}"
    response = requests.get(url, headers=headers)
    assert response.status_code == 206, f"status code: {response.status_code}"
    return response


def request_single_range(url, /, start: int, stop: int, headers=dict()):
    headers["Range"] = f"bytes={start}-{stop - 1}"
    response = requests.get(url, headers=headers)
    assert response.status_code == 206, f"status code: {response.status_code}"
    return response


def request_single_ranges_blocking(url, ranges, headers=dict()):
    for start, stop in ranges:
        yield request_single_range(url, start=start, stop=stop, headers=headers)


def request_single_ranges_threading(url, ranges, headers=dict(), num_workers=0):
    if num_workers <= 0:
        num_workers = len(ranges)
    if num_workers > len(ranges):
        num_workers = len(ranges)

    responses = []

    def worker(start, stop):
        response = request_single_range(url, start=start, stop=stop, headers=headers)
        responses.append(response)

    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        for start, stop in ranges:
            executor.submit(worker, start, stop)

    assert len(responses) == len(ranges)
    return responses


async def request_single_range_async(url, /, start, stop, headers=dict()):
    headers["Range"] = f"bytes={start}-{stop - 1}"
    async with aiohttp.ClientSession() as session:
        async with session.get(url, headers=headers) as response:
            assert response.status == 206, f"status code: {response.status}"
            return await response.read()


def request_single_ranges_async(url, ranges, headers):
    async def request_ranges():
        tasks = []
        for start, stop in ranges:
            task = request_single_range_async(url, start, stop, headers)
            tasks.append(task)
        return await asyncio.gather(*tasks)

    loop = asyncio.get_event_loop()
    responses = loop.run_until_complete(request_ranges())
    return responses


if __name__ == "__main__":
    filename = "benchmark/tree.root"

    port = 8080
    base_path = "http://ec2-18-118-186-39.us-east-2.compute.amazonaws.com/"
    file_url = base_path + filename

    print(f"file: {file_url}")
    assert check_file_availability(file_url), f"file {file_url} not available"

    tree_name = "Events"
    branch_name = "position.z"
    ranges = get_ranges(file_url, tree_name=tree_name, branch_name=branch_name)
    # ranges = ranges[:10]
    # ranges = [(0,10), (10,20), (20,30)]
    # ranges should be a list of (n, n+10) for n in [0, 10, 20, ...]
    step = 1
    ranges = [(n, n + step) for n in range(0, 1000, step)]
    average_basket_size = sum([stop - start for start, stop in ranges]) / len(ranges)
    print(f"number of baskets for branch {branch_name}: {len(ranges)}")
    print(f"total number of bytes: {sum([stop - start for start, stop in ranges])}")
    print(f"average basket size: {average_basket_size:.2f} bytes")

    def benchmark_whole_file():
        raise NotImplementedError  # too expensive
        time_start = time.time()
        response = requests.get(file_url)
        time_elapsed = time.time() - time_start
        return time_elapsed

    def benchmark_multipart():
        time_start = time.time()
        response = request_multipart_range(file_url, ranges=ranges)
        time_elapsed = time.time() - time_start
        return time_elapsed

    def benchmark_sequential_blocking():
        time_start = time.time()
        # use the generator
        responses = [
            response
            for response in request_single_ranges_blocking(file_url, ranges=ranges)
        ]
        time_elapsed = time.time() - time_start
        return time_elapsed

    def benchmark_threading(num_workers):
        time_start = time.time()
        responses = request_single_ranges_threading(
            file_url, ranges=ranges, num_workers=num_workers
        )
        time_elapsed = time.time() - time_start
        return time_elapsed

    def benchmark_async():
        time_start = time.time()
        responses = request_single_ranges_async(file_url, ranges=ranges, headers=dict())
        time_elapsed = time.time() - time_start
        return time_elapsed

    # multipart
    time_elapsed = benchmark_multipart()
    print(f"method: multipart. time elapsed: {time_elapsed:.2f} seconds")

    # sequential blocking
    # time_elapsed = benchmark_sequential_blocking()
    # print(f"method: sequential blocking. time elapsed: {time_elapsed:.2f} seconds")

    # threading
    for num_workers in [20, 4, 0]:
        time_elapsed = benchmark_threading(num_workers)
        print(
            f"method: threading with {num_workers} workers. time elapsed: {time_elapsed:.2f} seconds"
        )

    # asyncio
    time_elapsed = benchmark_async()
    print(f"method: asyncio. time elapsed: {time_elapsed:.2f} seconds")
