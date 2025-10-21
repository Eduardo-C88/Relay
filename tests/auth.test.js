const request = require("supertest");
jest.mock("../src/database", () => ({
  query: jest.fn().mockImplementation((sql, params) => {
    if (sql.includes("SELECT * FROM users WHERE email")) {
      if (params[0] === "alice@example.com") {
        return Promise.resolve({
          rows: [{ id: 1, email: "alice@example.com", password: "1234" }],
        });
      } else {
        return Promise.resolve({ rows: [] });
      }
    }
    return Promise.resolve({ rows: [] });
  }),
}));

const app = require("../src/authServer");

describe("Servidor de autenticação", () => {
  it("POST /auth/login deve autenticar utilizador válido", async () => {
    const res = await request(app)
      .post("/auth/login")
      .send({ email: "alice@example.com", password: "1234" });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("accessToken");
    expect(res.body).toHaveProperty("refreshToken");
  });

  it("POST /auth/login deve falhar com utilizador inexistente", async () => {
    const res = await request(app)
      .post("/auth/login")
      .send({ email: "unknown@example.com", password: "1234" });

    expect(res.statusCode).toBe(400);
  });
});
