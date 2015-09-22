# Resolute Saga

Saga pattern for resolute

# Setup
1. Take out a consul session
2. Link events to source addresses
3. Register saga handler
4. Discover saga events to subscribe to
5. Read saga log
6. Discover saga timeouts and intervals to setup
7. Wait for events

# Live
1. Receive events from subscriptions
2. Translate events into saga ids
3. Queue events, timeouts and intervals against a saga id
4. Purge any events, timeouts and intervals present in saga log
5. Detect work needed on a saga id
6. Attempt to take out lock on saga id

# Locked
1. Hydrate saga
2. Play events, timeouts and intervals against saga
3. Record events, timeouts, intervals in saga log
4. Write saga log
5. Unlock saga

# Unable to get lock
1. Queue 