'use strict'

const express = require('express')
const prometheus = require('prom-client')

const app = express()

const TEST_VAR = process.env.TEST_VAR || ':-('
const PORT = process.env.PORT || 8080

const metricsInterval = prometheus.collectDefaultMetrics()
const usersTotal = new prometheus.Counter({
  name: 'users_total',
  help: 'Total number of users',
  labelNames: ['user']
})
const httpRequestDurationMicroseconds = new prometheus.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.10, 5, 15, 50, 100, 200, 300, 400, 500]  
})

const emulateUser = (min = 1, max = 10) => {
  const n = Math.floor(Math.random() * (max - min + 1) + min)
  return `user${n}`
} 

// it runs before every request
app.use((req, res, next) => {
  res.locals.startEpoch = Date.now()
  next()
})

app.get('/app', (req, res, next) => {
  setTimeout(() => {
    const user = emulateUser()
    usersTotal.inc({ user })
    res.json({ message: `[${TEST_VAR}] All good so far :-)` })
    next()
  }, Math.round(Math.random() * 200))
})

app.get('/app-metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType)
  res.end(prometheus.register.metrics())
})

// it runs after every request
app.use((req, res, next) => {
  const responseTimeInMs = Date.now() - res.locals.startEpoch
  httpRequestDurationMicroseconds
    .labels(req.method, req.route.path, res.statusCode)
    .observe(responseTimeInMs)
  next()
})

const server = app.listen(PORT, () => {
  console.log(`Example app listening on port ${PORT}!`)
})
