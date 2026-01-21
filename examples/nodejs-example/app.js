const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Simulate database call
async function queryDatabase(userId) {
  const delay = Math.random() * 100;
  await new Promise(resolve => setTimeout(resolve, delay));

  // Simulate occasional slow queries
  if (Math.random() < 0.1) {
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return {
    id: userId,
    name: `User ${userId}`,
    email: `user${userId}@example.com`,
    createdAt: new Date().toISOString()
  };
}

// Simulate external API call
async function fetchExternalData(resource) {
  const delay = Math.random() * 200;
  await new Promise(resolve => setTimeout(resolve, delay));

  // Simulate occasional failures
  if (Math.random() < 0.05) {
    throw new Error('External API temporarily unavailable');
  }

  return {
    resource,
    data: `External data for ${resource}`,
    timestamp: new Date().toISOString()
  };
}

// Routes
app.get('/', (req, res) => {
  console.log('Health check requested');
  res.json({
    status: 'ok',
    service: 'nodejs-example',
    timestamp: new Date().toISOString()
  });
});

app.get('/user/:id', async (req, res) => {
  try {
    const userId = req.params.id;
    console.log(`Fetching user ${userId}`);

    const user = await queryDatabase(userId);
    res.json(user);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

app.get('/api/:resource', async (req, res) => {
  try {
    const resource = req.params.resource;
    console.log(`Fetching external resource: ${resource}`);

    const data = await fetchExternalData(resource);
    res.json(data);
  } catch (error) {
    console.error('Error fetching external data:', error);
    res.status(503).json({ error: error.message });
  }
});

app.post('/api/process', async (req, res) => {
  try {
    const { items } = req.body;
    console.log(`Processing ${items?.length || 0} items`);

    if (!items || !Array.isArray(items)) {
      return res.status(400).json({ error: 'Invalid request: items array required' });
    }

    // Simulate processing each item
    const results = [];
    for (const item of items) {
      await new Promise(resolve => setTimeout(resolve, 50));
      results.push({ item, processed: true, timestamp: new Date().toISOString() });
    }

    res.json({
      count: results.length,
      results
    });
  } catch (error) {
    console.error('Error processing items:', error);
    res.status(500).json({ error: 'Processing failed' });
  }
});

app.get('/error', (req, res) => {
  console.error('Intentional error triggered');
  throw new Error('Intentional error for testing error tracking');
});

app.get('/slow', async (req, res) => {
  console.log('Slow endpoint called');

  // Simulate slow operation
  await new Promise(resolve => setTimeout(resolve, 2000));

  res.json({
    message: 'This was a slow operation',
    duration: '2 seconds'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
  console.log(`OpenTelemetry instrumentation: ${process.env.OTEL_SERVICE_NAME || 'not configured'}`);
});
