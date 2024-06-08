# BOSH DNS Lookups

## Installation
```bash
cf push -f manifest.yml
```

## Usage
curl https://boshdns.yourcf.dom/lookup/instance_group?query_flags=s4&deployment='*'&network='*'

"boshdns" provides a GET interface to executing on-platform DNS
queries.  [BOSH DNS](https://bosh.io/docs/dns/) provides a unique
interface to query placement of various VMs.  The "instance_group"
indicates which VMs, and can be limited by specifying network,
and specific deployments.

The query_flag can further limit queries to
- s<N:int> - healthiness (0=default, 1=unhealthy, 3=healthy, 4=all)
- a<N:int> - availability zone
- i<N:int> - instance ID (aka index number)
- m<G:guid> - numerical guid (dashes included)
- y<N:int> - synchronous healthcheck (0=get retrieve, 1=health-check)
- g<N:int> - group N is the global instance group id

## Examples

Query for all diego cells
curl https://boshdns.dom/lookup/diego-cell?query-flags=s1
Requests all unhealthy diego cells

## Schema
curl https://boshdns.dom/ will yield a swagger page

## Developing
bosh-dns-lookup uses FastAPI.  A ```fastapi dev boshdns.py''' will
yield a testable instance.  Note that the DNS lookup just does a
simple local DNS lookup.
