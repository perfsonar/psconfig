import datetime
import isodate

def duration_to_seconds(iso):
    """Convert an ISO 8601 string to a timdelta and return total seconds
        Returns float"""
    try:
        duration = isodate.parse_duration(iso)
    except isodate.isoerror.ISO8601Error:
        raise ValueError("Invalid ISO duration")
    if not isinstance(duration, datetime.timedelta):
        raise ValueError("Cannot support months or years")
    return duration.total_seconds()
