#!/usr/bin/env python3
import urllib.request
import json

# Fetch regions
print("Testing PSGC API structure...")
print("=" * 60)

regions_url = "https://psgc.gitlab.io/api/regions/"
with urllib.request.urlopen(regions_url) as response:
    regions = json.loads(response.read())

# Find CALABARZON
calabarzon = next((r for r in regions if 'calabarzon' in r['name'].lower()), None)
if calabarzon:
    region_code = calabarzon['code']
    print(f"✓ CALABARZON code: {region_code}")
    
    # Fetch provinces
    prov_url = f"https://psgc.gitlab.io/api/regions/{region_code}/provinces/"
    with urllib.request.urlopen(prov_url) as response:
        provinces = json.loads(response.read())
    
    # Find Laguna
    laguna = next((p for p in provinces if p['name'].lower() == 'laguna'), None)
    if laguna:
        province_code = laguna['code']
        print(f"✓ Laguna code: {province_code}")
        
        # Try endpoint 1: region/province/cities
        city_url_1 = f"https://psgc.gitlab.io/api/regions/{region_code}/provinces/{province_code}/cities/"
        try:
            with urllib.request.urlopen(city_url_1) as response:
                cities = json.loads(response.read())
            print(f"\n✓ Endpoint 1 WORKS (region/province/cities):")
            print(f"  URL: {city_url_1}")
            print(f"  Cities found: {len(cities)}")
        except urllib.error.HTTPError as e:
            print(f"\n✗ Endpoint 1 FAILED ({e.code}):")
            print(f"  URL: {city_url_1}")
            
            # Try alternative endpoint
            city_url_2 = f"https://psgc.gitlab.io/api/provinces/{province_code}/cities/"
            try:
                with urllib.request.urlopen(city_url_2) as response:
                    cities = json.loads(response.read())
                print(f"\n✓ Endpoint 2 WORKS (province/cities):")
                print(f"  URL: {city_url_2}")
                print(f"  Cities found: {len(cities)}")
                if cities:
                    print(f"  Sample cities: {', '.join([c['name'] for c in cities[:3]])}")
            except urllib.error.HTTPError as e2:
                print(f"\n✗ Endpoint 2 also FAILED ({e2.code}):")
                print(f"  URL: {city_url_2}")
