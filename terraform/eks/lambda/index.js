// Lambda authorizer to verify CloudFront secret header
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const cloudfrontSecret = process.env.CLOUDFRONT_SECRET;
    const headerValue = event.headers['x-origin-verify'];
    
    // Verify the secret header
    if (headerValue === cloudfrontSecret) {
        console.log('Authorization successful');
        return {
            isAuthorized: true
        };
    }
    
    console.log('Authorization failed - invalid or missing header');
    return {
        isAuthorized: false
    };
};
