/**
 * Simple health check endpoint for AWS ALB
 * Returns a 200 status code with a basic health status
 */
export default defineEventHandler(() => {
  return {
    status: 'ok',
    timestamp: new Date().toISOString()
  }
})