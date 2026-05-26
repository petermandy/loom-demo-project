const events = {};

export function subscribe(eventName, callback) {
  if (!events[eventName]) {
    events[eventName] = [];
  }
  events[eventName].push(callback);
  
  return () => {
    events[eventName] = events[eventName].filter(cb => cb !== callback);
  };
}

export function publish(eventName, payload) {
  if (events[eventName]) {
    events[eventName].forEach(callback => {
      callback(payload);
    });
  }
}
