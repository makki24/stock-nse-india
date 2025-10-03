module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
  coverageThreshold: {
    global: {
      branches: 89,
      functions: 100,
      lines: 100,
      statements: 99.5
    }
  },
  coverageReporters: ['json', 'lcov', 'text', 'clover']
}
