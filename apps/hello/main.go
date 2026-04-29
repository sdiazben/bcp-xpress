package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	target := os.Getenv("TARGET")
	if target == "" {
		target = "World"
	}
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello, %s!\n", target)
	})
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
