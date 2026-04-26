const { add, subtract, multiply, divide, isEven } = require('../index');

describe('Unit Tests', () => {
  test('should return sum of two numbers', () => {
    expect(add(2, 3)).toBe(6);
  });

  test('should return difference of two numbers', () => {
    expect(subtract(5, 3)).toBe(2);
  });

  test('should return product of two numbers', () => {
    expect(multiply(4, 3)).toBe(12);
  });

  test('should return division of two numbers', () => {
    expect(divide(10, 2)).toBe(5);
  });

  test('should check if number is even', () => {
    expect(isEven(4)).toBe(true);
    expect(isEven(5)).toBe(false);
  });
});
