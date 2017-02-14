# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Dynomizer.Repo.insert!(%Dynomizer.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Dynomizer.Repo
alias Dynomizer.Schedule, as: S
alias Dynomizer.NumericParameter, as: NP

s = Repo.insert!(%S{application: "jim-qa",
                    dyno_type: "web",
                    manager_type: "Manager::Web::NewRelic::V2::ResponseTime",
                    schedule: "3 14 * * *",
                    description: "lunch time bump",
                    enabled: true,
                    notify: false,
                    url: "https://jim-qa.candidev.com/users/sign_in",
                    scale_up_on_503: false,
                    new_relic_account_id: "new-relic-foobar",
                    new_relic_api_key: "new-relic-api-key",
                    new_relic_app_id: "new-relic-app-id"})

Repo.insert!(%NP{schedule_id: s.id, name: "minimum", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "maximum", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "notify_quantity", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "notify_after", rule: "+2", min: 0, max: 100})

Repo.insert!(%NP{schedule_id: s.id, name: "upscale_quantity", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "upscale_sensitivity", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "upscale_timeout", rule: "+2", min: 0, max: 100})

Repo.insert!(%NP{schedule_id: s.id, name: "downscale_quantity", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "downscale_sensitivity", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "downscale_timeout", rule: "+2", min: 0, max: 100})

Repo.insert!(%NP{schedule_id: s.id, name: "minimum_response_time", rule: "+2", min: 0, max: 100})
Repo.insert!(%NP{schedule_id: s.id, name: "maximum_response_time", rule: "+2", min: 0, max: 100})
