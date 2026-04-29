package main

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Hello from BCP Xpress! 🚀",
			"env":     getEnv("APP_ENV", "dev"),
			"team":    getEnv("TEAM", "platform"),
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
	})

	port := getEnv("PORT", "8080")
	http.ListenAndServe(":"+port, nil)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
