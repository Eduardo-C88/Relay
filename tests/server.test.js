const request = require("supertest");

// Mock da base de dados (tem de vir antes do require do app)
jest.mock("../src/database", () => ({
  query: jest.fn().mockResolvedValue({ rows: [{ id: 1, name: "Test User" }] }),
  connect: jest.fn().mockResolvedValue({
    query: jest.fn().mockResolvedValue({ rows: [] }),
    release: jest.fn(),
  }),
}));

const app = require("../src/server"); // importa o app (não inicia servidor)

describe("Testa /users", () => {
  it("Deve responder com status 200", async () => {
    const res = await request(app).get("/users");
    expect(res.statusCode).toBe(200);
  });
});

afterAll(() => {
  jest.clearAllMocks(); // limpa todos os mocks
});
