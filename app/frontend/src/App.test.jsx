import { render, screen, waitFor } from "@testing-library/react";
import "@testing-library/jest-dom";
import App from "./App";

jest.mock("./api", () => ({
  get: jest.fn(() => Promise.reject(new Error("No response from server"))),
}));

test("renders BMI & Health Tracker header", async () => {
  // Suppress console errors during test
  const consoleSpy = jest.spyOn(console, "error").mockImplementation();

  render(<App />);
  const headerElement = screen.getByText(/BMI & Health Tracker/i);
  expect(headerElement).toBeInTheDocument();

  // Wait for async operations to complete
  await waitFor(() => {
    expect(headerElement).toBeInTheDocument();
  });

  // Restore console
  consoleSpy.mockRestore();
});
