const request = require("supertest");
const app = require("./server"); // Assuming we export app for testing

describe("GET /health", () => {
  it("should return status ok", async () => {
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
  });
});
