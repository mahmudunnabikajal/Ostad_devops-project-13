import { render, screen } from "@testing-library/react";
import "@testing-library/jest-dom";
import App from "./App";

test("renders BMI & Health Tracker header", () => {
  render(<App />);
  const headerElement = screen.getByText(/BMI & Health Tracker/i);
  expect(headerElement).toBeInTheDocument();
});
