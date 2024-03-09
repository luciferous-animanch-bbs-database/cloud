locals {
  flags = {
    lambda = {
      sqs_trigger = {
        entry_parser         = true
        thumbnail_downloader = true
      }
    }
  }
}