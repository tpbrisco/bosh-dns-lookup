#!/usr/bin/env python

import os
import dns.resolver
from fastapi import FastAPI
from fastapi.responses import RedirectResponse
import starlette.status as status

resolver = dns.resolver.Resolver()
resolver.timeout = 5

# determine dns lookup behavior
am_cf_deployed = False
if os.getenv('VCAP_APPLICATION'):
    am_cf_deployed = True

app = FastAPI(
    title='boshdns',
    description='Do BOSH DNS Lookups',
    summary='See https://bosh.io/docs/dns/ for field details',
    version='0.1.0')


def get_dns_rr(name: str) -> list:
    '''get_dns_rr(hostname) - get 'A' records and return an array of them'''
    try:
        ans = resolver.resolve(name, 'A')
    except dns.resolver.NXDOMAIN as e:
        # nothing to do, just no data is available
        # would be better to return "not found", but for simplicity ...
        return list()
    except dns.resolver.NoNameservers as e:
        return list()
    resp = list()
    for r in ans:
        resp.append(r.to_text())
    return resp


@app.get("/", include_in_schema=False)
def main():
    '''redirect to swagger interface, could be /redoc for ReDoc format'''
    return RedirectResponse(url="/docs", status_code=status.HTTP_302_FOUND)


@app.get("/lookup/{instance_group}")
def dns_lookup(instance_group: str,
               query_flags: str = "s4",
               deployment: str = '*',
               network: str = "*") -> dict:
    # non-CF behavior is to just look up a hostname
    name = instance_group
    if am_cf_deployed:
        # if we're in CF, formulate a BOSH DNS query
        name = f"q-{query_flags}.{instance_group}.{network}.{deployment}.bosh"

    addresses = get_dns_rr(name)
    return {
        "name": name,
        "instance_group": instance_group,
        "query_flags": query_flags,
        "deployment": deployment,
        "network": network,
        "addresses": addresses
    }
