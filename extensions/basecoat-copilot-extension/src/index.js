import { createServer } from "node:http";

const port = Number(process.env.PORT ?? "3000");

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(payload));
}

const server = createServer((req, res) => {
  if (req.url === "/healthz" && req.method === "GET") {
    sendJson(res, 200, {
      status: "ok",
      service: "basecoat-copilot-extension"
    });
    return;
  }

  if (req.url?.startsWith("/api/extension/")) {
    sendJson(res, 501, {
      error: "not_implemented",
      message: "Extension route scaffolded; implementation tracked by #1129 and #1130."
    });
    return;
  }

  sendJson(res, 404, {
    error: "not_found"
  });
});

server.listen(port, () => {
  console.log(`basecoat-copilot-extension listening on :${port}`);
});
