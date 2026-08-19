# Day-Date Developer Documentation

Welcome to the Day-Date codebase documentation. This folder provides a detailed reference for every layer, class, function, enum, and provider in the application.

## Documentation Index

| Document | Contents |
|:---------|:---------|
| [architecture.md](architecture.md) | Clean Architecture layers, dependency flow, data flow lifecycle |
| [core.md](core.md) | Constants, failure types, time utility functions, `FreeSlot` |
| [domain.md](domain.md) | Entities (`TimeBlock`, `TaskTarget`, `ScheduleDeviation`), enums, repository interface, use cases |
| [data.md](data.md) | Hive models, type adapters, model mappers, `LocalScheduleDatasource`, `ScheduleRepositoryImpl` |
| [application.md](application.md) | `PlannerService` algorithm (full step-by-step), result types, `_TargetAllocation`, provider wiring |
| [presentation.md](presentation.md) | Screens, widgets, UI state management, user interaction flows |
| [testing.md](testing.md) | Test structure, test groups, how to add new tests, coverage summary |

## Quick Navigation

- **"How does the algorithm work?"** → [application.md § PlannerService](application.md#plannerservice)
- **"How do I add a new entity field?"** → [domain.md § Adding Fields](domain.md#adding-a-new-field-to-an-entity) + [data.md § Model Update Checklist](data.md#model-update-checklist)
- **"How do I add a new deviation type?"** → [domain.md § DeviationType](domain.md#deviationtype) + [data.md § Mapper Updates](data.md#scheduledeviation-mappers)
- **"How does reactivity work?"** → [application.md § Providers](application.md#riverpod-providers)
- **"How does first-launch seeding work?"** → [data.md § ScheduleRepositoryImpl.seedIfEmpty](data.md#seedifempty)
