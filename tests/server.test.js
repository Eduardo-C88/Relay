const request = require("supertest");
const express = require("express");
jest.mock("../src/database", () => ({
  query: jest.fn().mockResolvedValue({ rows: [{ id: 1, name: "Test User" }] }),
  connect: jest.fn().mockResolvedValue({
    query: jest.fn(),
    release: jest.fn(),
  }),
}));

const app = require("../src/server"); // Vamos já adaptar isto

describe("Servidor principal", () => {
  it("GET /users deve responder com lista de utilizadores (mock)", async () => {
    const res = await request(app).get("/users");
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
