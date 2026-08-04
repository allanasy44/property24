import json
from functools import wraps

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods


def api_view(methods):
    def decorator(view_func):
        @csrf_exempt
        @require_http_methods([*methods, "OPTIONS"])
        @wraps(view_func)
        def wrapped(request, *args, **kwargs):
            if request.method == "OPTIONS":
                return JsonResponse({}, status=204)
            return view_func(request, *args, **kwargs)

        return wrapped

    return decorator


def parse_json_body(request):
    try:
        return json.loads(request.body.decode("utf-8") or "{}")
    except json.JSONDecodeError:
        return None


def error_response(message, status=400, errors=None):
    payload = {"error": message}
    if errors:
        payload["fields"] = errors
    return JsonResponse(payload, status=status)


def form_error_response(form):
    return error_response("Validation failed", errors=form.errors.get_json_data())
