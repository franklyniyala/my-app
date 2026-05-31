const express = require('express')
const path = require('path')

const port = process.env.PORT || 5006
const nodeEnv = process.env.NODE_ENV || 'development'

const app = express()

app.use(express.static(path.join(__dirname, 'public')))
app.set('views', path.join(__dirname, 'views'))
app.set('view engine', 'ejs')

// Middleware for logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`)
  next()
})

// Health check endpoint (for load balancers)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  })
})

// Main page
app.get('/', (req, res) => {
  res.render('pages/index', {
    environment: nodeEnv,
    timestamp: new Date().toISOString()
  })
})

// API endpoints
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    version: '1.0.0',
    environment: nodeEnv,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  })
})

app.get('/api/info', (req, res) => {
  res.json({
    name: 'Node.js Getting Started',
    description: 'Simple Express app deployed on AWS EC2',
    node_version: process.version,
    platform: process.platform
  })
})

// 404 handler
app.use((req, res) => {
  res.status(404).render('pages/404', {
    path: req.path
  })
})

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err.message)
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: nodeEnv === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  })
})

const server = app.listen(port, () => {
  console.log(`[${new Date().toISOString()}] Server started`)
  console.log(`Environment: ${nodeEnv}`)
  console.log(`Listening on port ${port}`)
})

server.keepAliveTimeout = 95 * 1000

process.on('SIGTERM', async () => {
  console.log('[SIGTERM] Gracefully shutting down...')
  if (server) {
    server.close(() => {
      console.log('[SIGTERM] HTTP server closed')
      process.exit(0)
    })
  }
})

process.on('SIGINT', async () => {
  console.log('[SIGINT] Gracefully shutting down...')
  if (server) {
    server.close(() => {
      console.log('[SIGINT] HTTP server closed')
      process.exit(0)
    })
  }
})
