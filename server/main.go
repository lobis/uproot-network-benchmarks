package main

import (
	"net/http"
	"log"
)

func main() {
	// Define the directory you want to serve files from.
	dir := "../files"

	// Create a file server handler for the specified directory.
	fileServer := http.FileServer(http.Dir(dir))

	// Register the file server handler with a route, typically the root ("/") path.
	http.Handle("/", fileServer)

	// Start the HTTP server on a specific port.
	port := "8080"
	log.Printf("Serving files from directory '%s' on :%s...\n", dir, port)
	err := http.ListenAndServe(":" + port, nil)
	if err != nil {
		log.Fatal("Error serving files: ", err)
	}
}
