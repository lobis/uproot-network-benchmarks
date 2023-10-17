import http.server
import socketserver
import os
import requests
import pathlib


def serve_files(directory: str, port: int):
    handler = http.server.SimpleHTTPRequestHandler
    handler.directory = directory

    httpd = socketserver.TCPServer(("", port), handler)

    print(f"Serving files from '{directory}' on port {port}")
    httpd.serve_forever()


def download_files(file_list: list[str], directory: str):
    pathlib.Path(directory).mkdir(parents=True, exist_ok=True)
    for file in file_list:
        filename = pathlib.Path(file).name
        if not os.path.exists(os.path.join(directory, filename)):
            print(f"Downloading {file} to {directory}")
            r = requests.get(file)
            with open(os.path.join(directory, filename), "wb") as f:
                f.write(r.content)


if __name__ == "__main__":
    port = 8000

    file_list = [
        "https://github.com/scikit-hep/scikit-hep-testdata/raw/v0.4.33/src/skhep_testdata/data/uproot-issue121.root",
    ]

    script_directory = os.path.dirname(os.path.abspath(__file__))
    files_directory = os.path.join(script_directory, "files")

    print(f"Files directory: {files_directory}")

    download_files(file_list, files_directory)
    print("Files in directory:")
    for file in os.listdir(files_directory):
        print(f" - {file}")

    serve_files(files_directory, port)
