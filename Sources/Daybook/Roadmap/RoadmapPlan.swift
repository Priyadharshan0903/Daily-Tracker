import Foundation

/// The 120-week engineering roadmap, baked in.
///
/// Pure static data — no state lives here. Progress against it is stored per
/// workspace in `RoadmapState`, keyed by week number and by the positional
/// indexes below, so nothing in this file may be reordered once shipped.
enum RoadmapPlan {

    // MARK: - Tracks

    /// The nine parallel tracks a week's work can be filed under.
    static let tracks = [
        "Go", "Databases", "Kubernetes", "Streaming", "DSA",
        "System Design", "Project", "Kotlin/JVM", "Visibility",
    ]

    // MARK: - Phases

    struct Phase: Identifiable, Equatable {
        let n: Int
        let from: Int
        let to: Int
        let theme: String
        var id: Int { n }
        var weekCount: Int { to - from + 1 }
    }

    static let phases: [Phase] = [
        Phase(n: 1, from: 1, to: 12, theme: "Go foundations · SQL foundations"),
        Phase(n: 2, from: 13, to: 24, theme: "Go concurrency · Transactions and MVCC"),
        Phase(n: 3, from: 25, to: 36, theme: "Production Go services · Migrations and schema evolution"),
        Phase(n: 4, from: 37, to: 48, theme: "Kubernetes core · Query performance and indexing"),
        Phase(n: 5, from: 49, to: 60, theme: "CKA · Redis and caching"),
        Phase(n: 6, from: 61, to: 72, theme: "Kafka and event-driven · Replication, partitioning, CDC"),
        Phase(n: 7, from: 73, to: 84, theme: "Observability, nginx, GitOps · Backups, HA, PITR"),
        Phase(n: 8, from: 85, to: 96, theme: "Operators and client-go · NoSQL breadth and storage internals"),
        Phase(n: 9, from: 97, to: 108, theme: "Kotlin and JVM · System design mastery"),
        Phase(n: 10, from: 109, to: 120, theme: "Interview mode and loops"),
    ]

    static func phase(forWeek week: Int) -> Phase {
        phases.first { week >= $0.from && week <= $0.to } ?? phases[0]
    }

    // MARK: - Weeks

    struct PlanWeek: Identifiable, Equatable {
        let n: Int
        /// The single thing this week is about.
        let focus: String
        /// The tracks running alongside it.
        let also: String
        /// The gate: a thing that exists by Sunday, or the week repeats.
        let checkpoint: String
        var id: Int { n }
    }

    static let totalWeeks = 120

    static func week(_ n: Int) -> PlanWeek {
        let index = min(max(n, 1), totalWeeks) - 1
        return weeks[index]
    }

    /// [focus, also running, checkpoint] — split out of the literal so the type
    /// checker never has to reason about a 120-element array of structs.
    private static let rawWeeks: [[String]] = [
        ["Go setup, syntax, types, zero values, iota, control flow", "DSA: arrays & hashing · DDIA ch.1", "Five small programs compile and run; five problems solved"],
        ["Slices and maps — backing arrays, cap growth, aliasing", "DSA: arrays & hashing", "You can explain why appending to a slice sometimes mutates another"],
        ["Structs, methods, pointer vs value receivers, embedding", "DSA: two pointers · DDIA ch.2", "A struct-based domain model with methods, tested"],
        ["Interfaces, implicit satisfaction, type switches, composition", "DSA: two pointers", "One program refactored to depend on an interface, not a struct"],
        ["Errors as values, wrapping, errors.Is/As, custom types", "DSA: sliding window · DDIA ch.3", "An error chain reaching the CLI with its context intact"],
        ["Packages, modules, project layout, dependency management", "DSA: sliding window", "Project v0 skeleton on GitHub with a real README"],
        ["Testing: table-driven, subtests, coverage, golden files", "DSA: prefix sums · DDIA ch.4", "80% coverage on your CLI tool"],
        ["Tooling, linting, Makefile, generics", "DSA: binary search", "make lint test runs clean in CI"],
        ["SQL: relational model, DDL, data types, constraints", "DSA: binary search on answer · DDIA ch.5", "Schema for the workflow engine designed and created"],
        ["SQL: joins, LATERAL, subqueries, CTEs", "DSA: stacks", "Twenty query exercises solved without looking up syntax"],
        ["Window functions, recursive CTEs, DISTINCT ON, aggregates", "DSA: monotonic stacks · DDIA ch.6", "A recursive CTE that walks your workflow DAG"],
        ["Phase review. Ship v0. Re-solve every failed problem", "Rest earned", "v0 runs a YAML workflow end to end; blog post drafted"],
        ["Goroutines, channels, select, directionality", "DSA: linked lists · DDIA ch.7", "A three-stage pipeline passing data with no leaks"],
        ["context — cancellation, deadlines, propagation", "DSA: linked lists", "Every function in v0 takes and respects a context"],
        ["sync primitives, atomic, the memory model, -race", "DSA: trees I", "A deliberate data race found and fixed by the race detector"],
        ["Worker pools, fan-in/out, semaphores, errgroup", "DSA: trees I — timed 35 min from here on", "A bounded worker pool with graceful shutdown"],
        ["ACID, isolation levels, the anomaly catalogue", "DSA: trees II", "Dirty read, non-repeatable read and phantom reproduced in psql"],
        ["Lost update and write skew; optimistic vs pessimistic", "DSA: trees II", "Write skew reproduced, then prevented two different ways"],
        ["Postgres MVCC: xmin/xmax, snapshots, visibility rules", "DSA: tries", "You can predict what a second session sees before running it"],
        ["Row locks, SKIP LOCKED, advisory locks, deadlocks", "DSA: heaps and top-K", "A working job queue on FOR UPDATE SKIP LOCKED"],
        ["SSI vs 2PL, serialization failures, retry loops", "DSA: heaps and top-K", "The queue survives 50 concurrent workers with no double-processing"],
        ["VACUUM, bloat, autovacuum, long transactions, XID wraparound", "DSA: graphs — BFS/DFS", "You've caused table bloat on purpose and measured it"],
        ["Sagas, compensation, the outbox pattern on paper", "DSA: graphs · SD: rate limiter", "A written design for cross-service consistency in your engine"],
        ["Phase review. Ship v1", "Rest earned", "v1 has a Postgres queue, retries with jitter, and zero races"],
        ["net/http, timeouts, chi routing, middleware", "DSA: topological sort · SD: URL shortener", "HTTP API with request IDs, timeouts and panic recovery"],
        ["log/slog, configuration, health checks, graceful shutdown", "DSA: union-find", "Service drains in-flight requests on SIGTERM"],
        ["pgx, pooling, batching, sqlc, repository layer", "DSA: Dijkstra · DDIA ch.8", "All queries type-safe and generated; no string SQL in handlers"],
        ["Transaction patterns in Go; retrying serialization failures", "DSA: graphs mixed", "A WithTx helper that retries correctly and is tested"],
        ["Migration tooling, versioning, dirty state, CI integration", "DSA: backtracking · SD: pastebin", "Migrations run automatically in CI against a Testcontainer"],
        ["Expand–contract; the dangerous DDL catalogue", "DSA: backtracking · DDIA ch.9", "Written notes on the lock each DDL statement takes"],
        ["CREATE INDEX CONCURRENTLY, NOT VALID constraints, type changes", "DSA: greedy", "A 10M-row table altered with no downtime, measured"],
        ["lock_timeout, statement_timeout, lock queue pile-ups", "DSA: greedy", "You've reproduced a lock pile-up and then prevented it"],
        ["Batched backfills with throttling and resumability", "DSA: intervals · SD: notification service", "A backfill that can be killed and resumed safely"],
        ["N/N+1 compatibility; migrations inside Kubernetes", "DSA: intervals", "Code that works against both old and new schema, tested"],
        ["gRPC, protobuf, interceptors", "DSA: DP 1D · DDIA ch.10", "An internal service-to-service call over gRPC with tracing"],
        ["Phase review. Ship v2", "Rest earned", "v2 has the full migration suite and a documented zero-downtime change"],
        ["Pods, lifecycle, probes, init containers, sidecars", "DSA: DP 1D · SD: web crawler", "v2 running on a local kind cluster"],
        ["Deployments, ReplicaSets, rollouts, rollbacks", "DSA: DP 2D · DDIA ch.11", "A rollout, a failed rollout, and a rollback performed"],
        ["StatefulSets, headless services, volume claim templates", "DSA: DP 2D", "Postgres running as a StatefulSet in your cluster"],
        ["Services, Ingress, Gateway API", "DSA: knapsack · Blog post 1", "Traffic reaching your service through an ingress"],
        ["ConfigMaps, Secrets, namespaces, quotas", "DSA: knapsack · DDIA ch.12", "Config externalised; no secrets baked into the image"],
        ["Index types: B-tree, GIN, GiST, BRIN, partial, covering", "DSA: LIS · Database Internals ch.1–2", "Every index in your schema justified in writing"],
        ["The planner, statistics, join strategies", "DSA: edit distance", "You can predict a plan before running EXPLAIN, and be right"],
        ["EXPLAIN (ANALYZE, BUFFERS) — reading plans properly", "DSA: DP mixed · SD: distributed cache", "Three slow queries found and fixed, with evidence"],
        ["Scheduling: requests, limits, QoS, eviction", "DSA: bit manipulation · DB Internals ch.3–4", "Resource requests set from real measurements, not guesses"],
        ["Affinity, anti-affinity, taints, tolerations, spread", "DSA: bit manipulation", "Workers spread across nodes with anti-affinity"],
        ["HPA; pg_stat_statements, pooling, PgBouncer", "DSA: math · SD: search autocomplete", "Autoscaling on a real metric; PgBouncer in front of Postgres"],
        ["Phase review. Ship v3. Neetcode 150 complete", "Rest earned", "v3 load-tested with a published p99; all 150 problems done once"],
        ["Book the CKA exam for week 60. Network model, CNI, kube-proxy", "DSA: Neetcode 250 begins · SDI Vol 1", "Exam booked and paid for. Non-negotiable"],
        ["CoreDNS, service discovery end to end, NetworkPolicy", "Redis: data types, TTL, eviction", "Default-deny policy applied, then selectively opened"],
        ["Redis persistence, pipelining, Lua, atomicity", "DSA: 250 · SDI Vol 1", "A rate limiter implemented as a Lua script"],
        ["Caching patterns; stampede, thundering herd, hot keys", "DSA: 250 · Meetup attended", "Cache-aside with jittered TTL in the engine"],
        ["Storage: PV, PVC, StorageClass, CSI, reclaim policies", "Redis: Streams, consumer groups", "A StatefulSet using dynamic provisioning"],
        ["kubeadm install, join, and the full upgrade workflow", "DSA: 250 · SDI Vol 1", "A three-node cluster built by hand, then upgraded"],
        ["etcd backup and restore; certificates; RBAC", "Troubleshooting drills begin", "etcd restored from snapshot after deliberate destruction"],
        ["Helm and Kustomize; troubleshooting drills continue", "DSA: 250 · SDI Vol 2", "Engine deployed by a Helm chart you wrote yourself"],
        ["Troubleshooting: pods, nodes, kubelet, static pods", "Break-and-fix daily", "Five self-inflicted cluster failures diagnosed and fixed"],
        ["Troubleshooting: DNS, networking, certs, crictl", "killer.sh session 1", "Simulator attempted; every miss written up"],
        ["Speed drills, imperative commands, docs navigation", "killer.sh session 2", "Full simulator completed under two hours"],
        ["CKA exam. Then ship v4", "Rest genuinely earned", "Certified. v4 running on the cluster with Redis"],
        ["Kafka: log abstraction, partitions, offsets, producers", "DSA: 250 · SDI Vol 2", "Producer writing to a local cluster with acks=all"],
        ["Consumer groups, rebalancing, offset management", "DSA: 250", "A consumer group surviving a rebalance without data loss"],
        ["Delivery semantics; why auto-commit loses messages", "SD: chat system", "At-least-once and at-most-once each proven and documented"],
        ["Idempotency keys, dedupe, exactly-once and its real cost", "DSA: 250", "Duplicate deliveries handled invisibly by the engine"],
        ["Transactions and the outbox pattern, implemented", "DSA: 250", "Outbox table plus relay, with no dual-write anywhere"],
        ["Replication, ISR, min.insync.replicas, retention, compaction", "SD: news feed", "You can explain what happens when a broker dies mid-write"],
        ["Schema Registry, evolution, compatibility modes", "DSA: 250", "A backwards-compatible schema change shipped"],
        ["Postgres streaming and logical replication; replication lag", "DSA: 250", "A read replica serving reads, with lag monitored"],
        ["Read-your-writes, routing reads, replica-safe code", "SD: hotel search with availability", "Read routing that never shows a user their own stale write"],
        ["Partitioning: range, list, hash; pruning; maintenance", "DSA: 250", "Events table partitioned by time, with automated maintenance"],
        ["Sharding, shard keys, Citus; CDC with Debezium", "DSA: 250", "Debezium streaming Postgres changes into Kafka"],
        ["Phase review. Ship v5", "Rest earned", "v5 event-driven end to end; blog post 4 published"],
        ["Prometheus, exporters, PromQL, cardinality", "DSA: 250 · SRE ch.1–3", "The four golden signals graphed for the engine"],
        ["Grafana dashboards, recording rules, alerting", "SD: booking with inventory locking", "An alert that fired for a real problem you caused"],
        ["OpenTelemetry tracing across services", "DSA: 250", "A trace spanning API → queue → worker → Postgres"],
        ["SLIs, SLOs, error budgets", "DSA: 250 · SRE ch.4–6", "Written SLOs for your own service, with rationale"],
        ["nginx: reverse proxy, upstreams, load balancing, keepalive", "SD: distributed job scheduler", "nginx in front of the engine, tuned"],
        ["nginx: TLS, caching, limit_req, timeouts, buffers", "DSA: 250 · SRE ch.7–9", "Rate limiting at the edge, verified under load"],
        ["Backups: pg_basebackup, WAL archiving, PITR", "DSA: 250", "A real restore drill completed and timed"],
        ["Failover, Patroni, synchronous replication trade-offs", "SD: dynamic pricing", "A failover performed; downtime measured"],
        ["GitOps with ArgoCD; progressive delivery", "DSA: 250 · SRE ch.10–12", "Cluster state reconciled from Git only"],
        ["Load testing with k6; capacity planning", "DSA: 250", "Published throughput and p99 under sustained load"],
        ["Chaos: kill nodes, brokers, and the primary database", "SD: payment ledger", "Engine survives each failure; every gap written up"],
        ["Phase review. Ship v6", "Rest earned", "v6 fully observable and GitOps-deployed; blog post 6"],
        ["client-go: clientsets, informers, listers, work queues", "DSA: 250 · Dynamo paper", "A program that watches pods and reacts to changes"],
        ["The controller pattern, level-triggered reconciliation", "DSA: 250", "You can explain why controllers are not event handlers"],
        ["Kubebuilder, CRD types, deepcopy, validation", "SD: metrics system", "A Workflow CRD installed in your cluster"],
        ["Reconcile loops, status subresource, conditions", "DSA: 250 · Raft paper", "A reconciler that converges from any starting state"],
        ["Finalizers, owner references, garbage collection", "DSA: 250", "Deleting a Workflow cleans up everything it created"],
        ["Admission webhooks; operator testing with envtest", "SD: web-scale search", "A validating webhook rejecting bad specs"],
        ["Storage engines: B-tree vs LSM, SSTables, compaction", "DSA: 250 · DB Internals revisit", "You can explain write, read and space amplification"],
        ["Cassandra: partition keys, clustering, tunable consistency", "DSA: 250 · Spanner paper", "A Cassandra data model designed and then critiqued"],
        ["DynamoDB single-table design; GSI vs LSI", "SD: flight aggregator", "A single-table design for the engine, on paper"],
        ["Elasticsearch: inverted index, analyzers, relevance", "DSA: 250 · Kafka paper", "Search over workflow runs, working"],
        ["ClickHouse and columnar OLAP; when relational is wrong", "DSA: 250 complete", "A written decision matrix: which store for which access pattern"],
        ["Phase review. Ship v7. Optionally start CKS", "Rest earned", "Workflows are native Kubernetes objects; blog post 7"],
        ["Kotlin: types, null safety, data and sealed classes", "DSA: hards begin · Resume rewrite starts", "A Kotlin CLI mirroring your week-8 Go one"],
        ["Extension functions, scope functions, generics, variance", "DSA: hards", "Idiomatic Kotlin, not Java with different syntax"],
        ["Coroutines, structured concurrency, dispatchers", "SD mock 1", "Each Go concurrency idiom mapped to its Kotlin equivalent"],
        ["Flow, cancellation, backpressure", "DSA: hards · STAR stories 1–4", "A streaming pipeline in Kotlin"],
        ["JVM: memory model, G1 and ZGC, reading thread dumps", "SD mock 2", "A heap dump read and interpreted"],
        ["Spring Boot: DI, configuration, Actuator", "DSA: hards · STAR stories 5–8", "A Spring service with health and metrics endpoints"],
        ["Spring Data JPA; @Transactional propagation; N+1", "SD mock 3", "JPA pitfalls demonstrated and fixed using your track B knowledge"],
        ["Testcontainers, JUnit 5, MockK", "DSA: hards · Resume final", "Kotlin service tested against a real Postgres"],
        ["Travel-domain designs, end to end", "SD mock 4 · Referral conversations begin", "Hotel booking designed cleanly in 45 minutes"],
        ["Design deep dives: the database layer of every design", "SD mock 5", "You name isolation levels and index strategy unprompted"],
        ["Behavioural rehearsal; the \"why leave Workday\" answer", "SD mock 6", "Eight stories told out loud without notes"],
        ["Phase review. Ship v8", "Rest earned", "Kotlin service running alongside Go; blog post 8"],
        ["Applications sent; referrals requested", "DSA: two hards a day · two SD mocks", "Fifteen applications out, five referrals requested"],
        ["Coding mocks with a human, not a screen", "DSA hards · SD mock", "Three mocks completed with written feedback"],
        ["Weak-pattern drilling from mock feedback", "DSA hards · SD mock", "Every recurring mistake has a written fix"],
        ["First real screens", "Maintain", "Feedback captured after every round, the same day"],
        ["Onsite loops begin", "Maintain", "Post-round notes written for each interviewer"],
        ["Loops continue; adjust from failures", "Maintain", "Weak areas from real loops drilled within 48 hours"],
        ["Loops continue", "Maintain", "Keep the rhythm; nothing new starts here"],
        ["Loops continue", "Maintain", "Keep the rhythm; nothing new starts here"],
        ["Offers; negotiation research", "Levels.fyi, Blind, local market data", "A number you can defend with data"],
        ["Negotiation", "—", "Competing timelines aligned where possible"],
        ["Decision", "—", "Decided on scope and team, not only on compensation"],
        ["Done. Write the retrospective", "—", "A post about the two years — the honest version"],
    ]

    static let weeks: [PlanWeek] = rawWeeks.enumerated().map { index, row in
        PlanWeek(n: index + 1, focus: row[0], also: row[1], checkpoint: row[2])
    }

    // MARK: - Weekly rhythm

    struct RhythmDay: Identifiable {
        /// 0 = Monday … 6 = Sunday.
        let index: Int
        let dow: String
        let slots: [String]
        var id: Int { index }
    }

    /// The slot that expands to the week's own focus line at render time.
    static let handsOnSlot = "Hands-on: core focus"

    private static let rawRhythm: [(String, [String])] = [
        ("Monday", ["One DSA problem", "20 min reading"]),
        ("Tuesday", ["One DSA problem", "20 min reading", handsOnSlot]),
        ("Wednesday", ["One DSA problem", "20 min reading"]),
        ("Thursday", ["One DSA problem", "20 min reading", handsOnSlot]),
        ("Friday", ["One DSA problem", "20 min reading"]),
        ("Saturday", ["System design study", "Project build"]),
        ("Sunday", ["Re-solve the week's failures", "Write notes", "Tick the checkpoint"]),
    ]

    static let rhythm: [RhythmDay] = rawRhythm.enumerated().map { index, row in
        RhythmDay(index: index, dow: row.0, slots: row.1)
    }

    /// Expands the placeholder slot into the week it belongs to.
    static func slotLabel(_ slot: String, week: PlanWeek) -> String {
        slot == handsOnSlot ? "Hands-on: \(week.focus)" : slot
    }
}
