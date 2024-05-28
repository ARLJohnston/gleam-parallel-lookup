import argv
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/httpc
import gleam/io
import gleam/list.{map}
import gleam/result
import nessie

pub fn main() {
  let domain = case argv.load().arguments {
    [domain] -> domain
    _ -> panic as "Program must be run with precisely one domain as an argument"
  }

  let subject: Subject(Response(String)) = process.new_subject()

  get_ips_from_url(domain)
  |> map(fn(x) {
    process.start(
      fn() {
        let res = fetch_page(x)
        process.send(subject, res)
      },
      False,
    )
  })

  let selector =
    process.new_selector()
    |> process.selecting(subject, function.identity)

  process.select(selector, 10_000)
  |> io.debug
}

fn get_ips_from_url(url: String) -> List(String) {
  let ipv4_addrs =
    nessie.lookup_ipv4(url, nessie.In, [])
    |> map(fn(x) { nessie.ip_to_string(nessie.IPV4(x)) })
    |> result.values

  let ipv6_addrs =
    nessie.lookup_ipv6(url, nessie.In, [])
    |> map(fn(x) { nessie.ip_to_string(nessie.IPV6(x)) })
    |> result.values

  list.concat([ipv4_addrs, ipv6_addrs])
}

fn fetch_page(addr: String) -> Response(String) {
  let url = "https://" <> addr
  let req = case request.to(url) {
    Ok(inner) -> inner
    Error(e) -> {
      io.debug(e)
      panic as { "Failed to create request from: " <> addr }
    }
  }

  let response = case httpc.send(req) {
    Ok(inner) -> inner
    Error(e) -> {
      io.debug(e)
      panic as { "Failed to receive httpc result for: " <> addr }
    }
  }

  response
}
