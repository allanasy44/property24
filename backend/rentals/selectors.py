from django.db.models import Q

from .models import Property


def property_search_queryset(params):
    properties = Property.objects.select_related("owner", "agent").prefetch_related("photos", "videos")
    query = params.get("q") or params.get("search")
    if query:
        properties = properties.filter(
            Q(title__icontains=query)
            | Q(description__icontains=query)
            | Q(address__icontains=query)
            | Q(city__icontains=query)
            | Q(suburb__icontains=query)
            | Q(property_type__icontains=query)
        )
    if params.get("city"):
        properties = properties.filter(city__iexact=params["city"])
    if params.get("suburb"):
        properties = properties.filter(suburb__iexact=params["suburb"])
    if params.get("property_type"):
        properties = properties.filter(property_type=params["property_type"])
    if params.get("type"):
        properties = properties.filter(property_type=params["type"])
    if params.get("rent_min"):
        properties = properties.filter(monthly_rent__gte=params["rent_min"])
    if params.get("rent_max"):
        properties = properties.filter(monthly_rent__lte=params["rent_max"])
    if params.get("bedrooms_min"):
        properties = properties.filter(bedrooms__gte=params["bedrooms_min"])
    if truthy(params.get("verified_only")):
        properties = properties.filter(listing_status=Property.ListingStatus.VERIFIED, owner__is_verified=True)
    return properties.filter(is_active=True).order_by("-created_at")


def truthy(value):
    return str(value).strip().lower() in {"1", "true", "yes", "on"}
