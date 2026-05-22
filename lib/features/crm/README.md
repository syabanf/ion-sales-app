# features/crm — Sales App surface

Hosts the **Sales App** experience for Sales Reps (PRD §CRM & Sales).
Lands in M4. Will own:

- Lead list + create lead
- Coverage check via map pin
- KTP OCR capture (Mode A photo + Mode B manual)
- Cable distance check (Potential vs Accept Excess flow)
- Order submission for broadband
- Read-only commission visibility

Follow the same shape as `features/auth/`:

```
features/crm/
├── data/                 API binding (Dio) + repository impl
├── domain/               Entities + repository interface
└── presentation/
    ├── bloc/             CRM-feature BLoCs (one per coherent screen group)
    └── pages/            Widgets
```
