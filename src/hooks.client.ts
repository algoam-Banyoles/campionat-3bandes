// Handle client-side errors
export const handleError = ({ error, event }: { error: Error; event: any }) => {
  console.error('Client error:', error, 'at', event.route?.id);
  return {
    message: "S'ha produït un error inesperat."
  };
};

// Client-side initialization
export function init() {
  // Any client-side initialization can go here
}
