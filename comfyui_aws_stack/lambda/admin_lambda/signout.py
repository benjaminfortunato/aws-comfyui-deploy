import os


def handler(event, context):
    # Use the provided redirect URL or default to the root path if not available
    redirect_url = os.environ.get('REDIRECT_URL', '/')

    return {
        'statusCode': 302,
        'headers': {
            'Set-Cookie': 'AWSELBAuthSessionCookie-0=; max-age=0',
            'Set-Cookie': 'AWSELBAuthSessionCookie-1=; max-age=0',
            'Access-Control-Allow-Methods': 'GET',
            'Location': redirect_url
        }
    }
