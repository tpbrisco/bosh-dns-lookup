#!/usr/bin/env python
'''Lookup BOSH DNS names'''
import os
import dns.resolver
from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from starlette import status
from pydantic import BaseModel

# intialize DNS resolver
resolver = dns.resolver.Resolver()

# determine dns lookup behavior
AM_CF_DEPLOYED = bool(os.getenv('VCAP_APPLICATION'))

# initialize FastAPI app
app = FastAPI(
    title='boshdns',
    description='Do BOSH DNS Lookups',
    summary='See https://bosh.io/docs/dns/ for field details',
    version='0.1.0')


# get_dns_rr return - include data and/or error message
class DnsAns(BaseModel):
    '''Response model for DNS Lookups'''
    reason: str | None
    addresses: list


# main entry point data returned
class BoshDnsAns(BaseModel):
    '''BOSH DNS Lookup model, with parameters and messages'''
    query: str | None = None
    instance_group: str
    query_flags: str
    deployment: str
    network: str
    addresses: list
    reason: str | None = None


def get_dns_rr(name: str) -> DnsAns:
    '''get_dns_rr(hostname) - get 'A' records and return an DnsAns
    including any reason code'''
    rr = DnsAns(reason=None, addresses=[])
    try:
        ans = resolver.resolve(name, 'A')
    except dns.resolver.NXDOMAIN as e:
        # nothing to do, just no data is available
        # would be better to return "not found", but for simplicity ...
        rr.reason = str(e)
        return DnsAns.model_validate(rr, strict=True)
    except dns.resolver.NoNameservers as e:
        rr.reason = str(e)
        return DnsAns.model_validatet(rr, strict=True)
    except dns.resolver.NoAnswer as e:
        # response, but no answer
        rr.reason = str(e)
        return DnsAns.model_validate(rr, strict=True)
    for r in ans:
        rr.addresses.append(r.to_text())
    return DnsAns.model_validate(rr, strict=True)


@app.get("/", include_in_schema=False)
def main():
    '''redirect to swagger interface, could be /redoc for ReDoc format'''
    return RedirectResponse(url="/docs", status_code=status.HTTP_302_FOUND)


@app.get("/lookup/{instance_group}")
def dns_lookup(instance_group: str,
               query_flags: str = "s4",
               deployment: str = '*',
               network: str = "*") -> BoshDnsAns:
    '''dns_lookup - use BOSH DNS format if we're deployed in cloud foundry,
    otherwise return a standard DNS lookup (test test, dev, etc)'''
    bd_ans = BoshDnsAns(
        instance_group=instance_group,
        query_flags=query_flags,
        deployment=deployment,
        network=network,
        addresses=[])
    # non-CF behavior is to just look up a hostname
    bd_ans.query = instance_group
    if AM_CF_DEPLOYED:
        # if we're in CF, formulate a BOSH DNS query
        bd_ans.query = f"q-{query_flags}.{instance_group}.{network}.{deployment}.bosh"

    ans = get_dns_rr(bd_ans.query)
    bd_ans.addresses = ans.addresses.copy()
    bd_ans.reason = ans.reason
    return BoshDnsAns.model_validate(bd_ans, strict=True)
