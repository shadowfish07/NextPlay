const path = require("node:path");

module.exports = {
  apps: [
    {
      name: "igdb-service",
      cwd: __dirname,
      script: "dist/igdb-service",
      interpreter: "none",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      env_file: path.join(__dirname, ".env"),
    },
  ],
};
