module.exports = {
  apps: [
    {
      name: "igdb-service",
      script: "dist/igdb-service",
      interpreter: "none",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      env_file: ".env",
    },
  ],
};
