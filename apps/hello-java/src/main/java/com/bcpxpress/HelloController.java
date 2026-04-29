package com.bcpxpress;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HelloController {

    @Value("${APP_ENV:dev}")
    private String env;

    @Value("${TEAM:platform}")
    private String team;

    @GetMapping("/")
    public Map<String, String> hello() {
        return Map.of(
            "message", "Hello from BCP Xpress!",
            "env",     env,
            "team",    team,
            "time",    Instant.now().toString()
        );
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }
}
