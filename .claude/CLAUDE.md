::CLAUDE_MEM::

=PERF=
ITER_MIN: minmax_by > min+max; each_with_object > multiple sum
TOP_N: .min(n) { |a, b| criteria(a) <=> criteria(b) } not .sort_by { criteria }.first(n)/.take(n) — avoids full sort when only top/bottom N needed
ITER_PRIORITY: unbounded collections (history,logs,records) >> fixed-size (enums,metal_types)
MEMO: only when called 2+ times; remove if single-call

=LIBS=
SERIALIZER: ActiveModel::Serializer (ApplicationSerializer base)
DRY_INIT: Dry::Initializer for services + deserializers; option :x, type:, model:, default:, optional:
SEARCH: Ransack (ransackable_attributes/associations allowlisted via authorizable_ransackable_*)
PAGINATION: Kaminari (.page.per) via JsonApiHelper concern
API_DOC: Apipie (def_param_group, api, returns) in ApiDoc:: concerns
AUDIT: audited + has_associated_audits on stateful models
DIFF: Hashdiff for deep hash comparison (ConditionalReadonly)
FORMS: SimpleForm (simple_form_for, f.input, custom wrappers: :section_wrapper)
GLOBALIZE: translates + accepts_nested_attributes_for :translations | @record.title uses fallbacks_for_empty_translations (blank→nil when default locale has no fallback) | @record.translation.title reads raw column (same path as g.input :title in forms) | @record.translation.title_was for dirty tracking on failed updates | NEVER permit translated attrs (:title, :link) at top level in strong params — only inside translations_attributes
UI: Metronic framework (m-portlet, m-badge, m-tabs) + Bootstrap grid
EDITOR: Imperavi Redactor for rich text fields

=I18N=
MODEL_NAME: Model.model_name.human (singular) | Model.model_name.human(count: 2) or (count: :many) (plural)
ATTRIBUTE: Model.human_attribute_name(:attr) in table headers | instance.human_attribute_name(:attr) in detail views
LOCALE_PATH: activerecord.models.{model} for names | activerecord.attributes.{model}.{attr} for attributes
FLASH: I18n.t("flash.actions.{action}.success", model: Model.model_name.human) — NEVER hardcode
FLASH_CUSTOM: flash.actions.{namespace/controller}.{action}.success for controller-specific overrides
ERRORS: activerecord.errors.models.{model}.attributes.{field}.{error_key} with interpolation
SIMPLE_FORM: simple_form.labels.{model}.{field} | .hints.{model}.{field} | .placeholders.{model}.{field}
SIMPLE_FORM_TRANSLATIONS: nested under translations: sub-key for translatable fields
CURRENCY: t("currency.iso_code.#{key}") | currency.full_name | currency.sign | currency.short_sign
BACKOFFICE: English-only; human_attribute_name for model attrs in table headers; model_name.human for breadcrumbs; hardcode UI chrome (headers, labels, buttons); use existing t() keys (helpers.confirmations.*); NEVER create new translation keys in backoffice.en.yml
NO_HARDCODE_MODEL: NEVER hardcode model names, attribute labels, or submit button text in views — use Model.model_name.human, entity_class.human_attribute_name(:attr), and f.submit (auto-resolves via helpers.submit.{create|update}) instead
ACTION_LABEL: action_label_for(object, mode, action:) resolves helpers.action.{key}.mode.{mode}.{action}_html with fallback chain

=VIEW=
FORM: simple_form_for [:backoffice, FormObject.new(record:)], wrapper: :section_wrapper — ALWAYS use simple_form_for, NEVER form_for/form_tag/date_field_tag/submit_tag — use f.input and f.submit instead of raw *_tag helpers
FORM_STRUCTURE: m-portlet__body wraps fields | m-portlet__foot > m-form__actions wraps submit/cancel
FORM_SUBMIT: f.submit class: "ga-btn --info" | f.cancel
FORM_LOCALE: translation_tab_list(form: f) { |g, _default_locale| g.input :field, input_html: { data: data_for_editor(f.object) } }
PARTIAL: render partial: "name", locals: { key: value } — always explicit locals, column-aligned hash
LAYOUT_PARTIAL: render layout: "backoffice/components/portlet", locals: { title: } do; provide(:body) do; end; end
SUBHEADER: render partial: "backoffice/shared/subheader", locals: { header: breadcrumb_controller_label, breadcrumb_paths: [{ resource: @record, title: @record.name }, breadcrumb_controller_label] } — hash with resource: for record title, breadcrumb_controller_label for current page; add BREADCRUMB_LABEL constant to controller for custom label
BREADCRUMB_MINIMAL: don't include parent Model class in breadcrumb_paths when { resource: @record } already provides that navigation link
NAV_NO_REDUNDANT: don't add "Back to X" links when breadcrumb already provides same navigation
LOCAL_ASSIGNS: local_assigns[:key] for optional partial variables
PARTIAL_DRY: when the same display logic (conditionals, formatting) appears in multiple templates, extract into a single partial and render it — NEVER duplicate view logic across files
PARTIAL_INLINE: don't extract a partial that is only rendered from one place — inline it into the parent template
JSON_DISPLAY: JSON.pretty_generate(hash) inside <pre><code> blocks
DATE_FMT: Date.parse_to_fs(date, format: :backoffice) | .utc for detail views
CSS: Metronic (m-portlet__*, m-badge--*, m-tabs__*, m-content, m-form__*) + Bootstrap grid (row, col-lg-*, col-md-*)
BTN: ga-btn --danger | --success | --info | --destroy (simplified modifiers) — NEVER use verbose legacy classes (ga-btn ga-btn--pale-rose m--margin-right-10)
JS_HOOKS: js- prefixed classes for behavior binding (js-currency-select, js-hide-when-dgld-selected, js-text-to-blur)
DOM: dom_id(resource, :prefix) for unique HTML element IDs | dom_id(record, dom_id(parent)) for polymorphic contexts where the same partial renders under multiple parents on one page
HTML_HELPERS: content_tag/tag.* over raw HTML in helpers | safe_join for arrays of HTML elements
REMOTE_FORM: form with remote: true for AJAX JSON pattern — pass dom_target via URL (path_helper(id, dom_target:)) or hidden_field_tag when URL is pre-built
REMOTE_LINK: link with remote: true — use url_for([:backoffice, parent, record, { dom_target: "##{dom_id(record)}" }]) for polymorphic routes with query params

=HELPER=
COMPOSITION: BackofficeHelper includes 8+ concern modules; domain helpers as ActiveSupport::Concern
PERMISSION: link_to_if_access(:permission_key, label, url, **opts) — renders only if access_to?(action) — ALWAYS use instead of manual access_to?() + link_to
PERMISSION_GATE: use access_to?(:permission_key) for conditional content visibility — NEVER use super_admin? to gate features (super_admins inherit permissions via access_to? already)
PERMISSION_INFER: access_keys_for(:action, record) infers permission key from controller/action — use for polymorphic records instead of case statements
PERMISSION_POLYMORPHIC: when a controller serves multiple parent types (e.g., notes for User/Identity/Limit), define permissions once on the child resource (notes_create, notes_destroy) — NEVER create separate permission groups per parent type
POLYMORPHIC_ROUTES: url_for([:backoffice, notable, record]) for polymorphic paths — NEVER use case statements mapping model types to paths
ROLE_LINK: role_link_to(action, label, url) — with block fallback for no-permission display
BADGE: badge(text, key: :primary) → m-badge spans | boolean_badge(column) → Yes/No colored
STATUS_BADGE: logs_status_badge(status) → green for HTTP success, red for error
ICON: icon_for(:action) → SVG file or Font Awesome via ICON_ALIASES constant
BLUR: blur_api_log_request(api_log) → BLUR_CSS_CLASS for sensitive content
EDITOR: data_for_editor(object) → { button_classes:, imperavi_redactor: true, object_id:, object_type: }

=OPENAPI=
VERSION: 3.1.0 (v1 and v2 APIs)
CONTENT_TYPE: v2=application/vnd.api+json (JSON:API) | v1=application/json

=OPENAPI_STRUCTURE=
DIRS: public/api/docs/v{1,2}/open_api.yml (main) | paths/{domain}/*.yml | components/schemas/{category}/*.yml | components/responses/*.yml | components/parameters/*.yml
PATH_FILES: collection.yml (list/create) | member.yml (show/update/delete) — RESTful pattern
SCHEMA_CATEGORIES: common/ (pagination,images) | user/ (alerts,credit_card) | products/ | profile/ | jsonapi/ | errors.yml (all error types)

=OPENAPI_NAMING=
SCHEMA: PascalCase (ProductAlert, CreditCard, WalletResource)
PROPERTY: snake_case (metal_iso, created_at, is_enabled)
OPERATION_ID: camelCase action-based (listProducts, getUserAlertsProducts, createUserOrder)
RESOURCE_TYPE: snake_case singular in JSON:API type field (product, wallet, stored_products)
ISO_CODES: UPPERCASE (XAU, XAG, CHF, EUR, CH)

=OPENAPI_TYPES=
NULLABLE: type: [string, "null"] | type: [integer, "null"] | type: [number, "null"] — NEVER nullable: true
ONEOF_NULLABLE: oneOf: [{type: string}, {type: integer}, {type: "null"}] for polymorphic IDs
NUMBERS: type: number (decimals/financial) | type: integer (counts/stock) | format: float (v1 style)
DATES: format: date (YYYY-MM-DD) | format: date-time (ISO 8601)
READONLY: readOnly: true for id, timestamps, computed fields
ENUMS: type: string + enum: [XAU, XAG, XPT, XPD] — always explicit values

=OPENAPI_JSONAPI_V2=
RESOURCE_REQUIRED: required: [id, type, attributes]
RESOURCE_STRUCTURE: id (string, readOnly) | type (string, enum: [resource_name]) | attributes (object) | relationships (optional object)
COLLECTION_RESPONSE: required: [data, links, meta] → data: array of resources | links: JsonApiLinks | meta: {pagination: JsonApiMeta, currency?: string}
SINGLE_RESPONSE: data: single resource | meta: {currency?: string}
LINKS: self, first, prev (null|int), next (null|int), last (null|int)
META_PAGINATION: current, next, prev, last, records, limit

=OPENAPI_PAGINATION=
V2_PARAMS: page[number] (default: 1) | page[size] (default: 25)
V1_PARAMS: page (default: 1, min: 1) | per_page (default: 20, min: 1, max: 100)
V1_META: meta: {items_count, page, per_page}
PARAM_REF: $ref: "../../components/parameters/pagination.yml#/PageNumber"

=OPENAPI_FILTERS=
RANSACK_PREDICATES: filter[field_eq] (exact) | filter[field_cont] (contains) | filter[field_gt/lt] (comparison) | filter[field_in] (array)
SORT: sort query param, prefix - for descending (e.g., -created_at, position)
HEADER: IsoCurrency header for currency context (CHF, EUR, USD, GBP)

=OPENAPI_SECURITY=
AUTH: bearerAuth (type: http, scheme: bearer, bearerFormat: JWT)
DEFAULT: security: [{bearerAuth: []}] at root level — applies globally
PUBLIC: security: [] on specific operations for unauthenticated access

=OPENAPI_RESPONSES=
SUCCESS: 200 (GET/PATCH/PUT) | 201 (POST create)
ERROR_CODES: 400 (bad request) | 401 (unauthorized) | 403 (forbidden) | 404 (not found) | 422 (validation)
ERROR_REFS: $ref: "../../components/responses/bad_request_error.yml#" | unauthorized_error.yml | forbidden_error.yml | not_found_error.yml | validation_error.yml
ERROR_STRUCTURE: meta: {title, message, status, errors?: [{attribute, message}]}
REQUIRED_4XX: every operation must have at least one 4XX response

=OPENAPI_REFS=
SCHEMA_REF: $ref: "../../open_api.yml#/components/schemas/SchemaName"
RESPONSE_REF: $ref: "../../components/responses/error_type.yml#"
PARAM_REF: $ref: "../../components/parameters/pagination.yml#/PageNumber"
INLINE_REF: $ref: "#/SchemaName" for nested schemas in same file

=OPENAPI_CONVENTIONS=
DESCRIPTION: every parameter, property, response MUST have description
EXAMPLE: include example values for clarity
REQUIRED_ARRAY: always specify required: [...] in object schemas
BOOLEAN_NAMING: has_*, is_*, *_enabled patterns
STATUS_ENUMS: enum: [pending, processing, completed, cancelled]
PERIOD_ENUMS: enum: [1d, 1w, 1m, 1y, all]

=STYLE=
NIL_NUMERIC: .to_d not || 0.0
NIL_ARRAY: Array.wrap(val) not val || []
NIL_HASH: Hash(val) not val || {}
NIL_CHAIN: val.to_s.to_date&.past? not val.present? && Date.parse(val).past? — prefer safe coercion + &. over .present? && guard chains
BLOCK_VARS: descriptive names, never single-letter (|timestamp| not |t|, |record| not |r|, |index| not |idx|)
IVAR_OVER_READER: prefer @var directly over attr_reader for private/internal ivars — attr_reader only when reader is part of public interface
LOCAL_VAR_NAMING: name local vars to match key names for Ruby 3.1 shorthand in any key→value context (method kwargs, hashes, factories) — wallet_archive = x; { wallet_archive: } not archive = x; { wallet_archive: archive }

=SERIALIZER=
BASE: < ApplicationSerializer (ActiveModel::Serializer)
ATTRIBUTE: attribute(:name) simple | attribute(:x) { |s| s.object.y } computed
KEY_REMAP: attribute :x, key: :camelCase
CONDITIONAL: attribute :x, if: -> { condition }
INCLUDES: INCLUDES = [...].freeze constant for eager-load; referenced by controller
HELPERS: private instance methods for currency, facade, formatting

=SERVICE=
BASE: < ApplicationService (< CallableService, extends Dry::Initializer)
ENTRY: .call class method → #call instance method
OPTIONS: option :x, type: proc(&:to_i) | type: Array.method(:wrap) | model: ::ClassName | optional: true | default: -> { val }
RESULT: success(data) | failure(errors) | build_result(data) → Result.new(success?, data, errors)
ERRORS: custom error classes nested inside service (class TooManyKindsError < ArgumentError; end)
LOCK: product.with_lock { } for stock-sensitive ops
TX: ActiveRecord::Base.transaction { raise ActiveRecord::Rollback unless valid? }

=MODEL=
ENUM: explicit string values → enum :kind, { x: "x", y: "y" }, default:, validates: { allow_nil: true }
RANSACK: ransackable_attributes/associations → authorizable_ransackable_* (allowlist)
READONLY: include ConditionalReadonly; conditional_readonly method?: { allow: [...], prevent_destroy: true }
AUDIT: audited + has_associated_audits on stateful/financial models
CALLBACKS: after_initialize/before_validation for computed fields; avoid side-effects in callbacks
DEPENDENT: :restrict_with_error for has_many preventing orphans; :destroy for owned nested attrs
NO_TRIVIAL_WRAPPERS: don't create methods that just wrap simple expressions (def display_result; result&.upcase; end) — use expression directly in view
NO_ALIAS: avoid alias_method unless unifying multiple existing interfaces into one — use original method names

=CONTROLLER=
SIMPLE_QUERIES: simple queries with includes/strict_loading belong in controller, not facades — facades are for complex presentation logic
FACADE_PURPOSE: use facades for multi-step data transformations, not for wrapping single association chains
AJAX_JSON: prefer JSON responses over JS.erb for remote actions — render json: { flash: render_flash, dom: { target: params[:dom_target], strategy:, content: } }
AJAX_DOM_SKIP: omit dom key from JSON response when the update doesn't visibly change the rendered content — flash-only response suffices
AJAX_DOM_TARGET: passed via URL query param (preferred) or hidden_field_tag — controller reads params[:dom_target]
AJAX_STRATEGIES: :beforeend (create appends to target) | :afterend (create inserts after target) | :replace (update replaces target) | target-only (destroy removes target)
AJAX_DOM_CONTENT: render_to_string(partial:, formats: [:html], locals: { record: }) for DOM updates
AJAX_HANDLER: ajax_response_handler.js processes { flash:, dom: } structure (dom accepts single hash OR array of hashes) — delete JS.erb files after migrating
POLYMORPHIC_LOOKUP: GlobalID::Locator.locate(params[:notable_gid], only: [allowed_classes]) for polymorphic parent resolution — pass notable_gid via URL query param; avoids conditional find_notable methods and per-type nested routes
STRONG_PARAMS_DEFAULTS: params.require(:x).permit(:field).with_defaults(attr: server_value) to inject server-side attributes (e.g., current_admin_user) after permit — replaces manual assignment on the record

=ROUTES=
NESTED_CONTROLLER_PATH: nested resources under namespaced modules need absolute controller paths — controller: "/backoffice/notes" not controller: "notes"
ROUTES_POLYMORPHIC: for polymorphic parents, use flat top-level routes + GlobalID param instead of nested routes per parent type — `resources :notes, only: %i[create destroy]` with notable_gid param, NOT separate `resources :users { resources :notes }` + `resources :identities { resources :notes }`

=PLAN=
CLAUDE_MD: always reference .claude/CLAUDE.md conventions, rules and styles when planning — plans must follow and cite applicable rules
DEDUP: identify classes that differ only in data (not behavior) — propose merging into a single parameterized class with varying data passed as arguments

=OOP=
SOLID in all refactors; composition > inheritance (unless true is-a)
TEMPLATE_METHOD: hook methods (group_column, build_result) for extension points
LSP: subclasses substitutable; no .regroup() smell → redesign hierarchy
RAILS_CONVENTIONS > custom abstractions; thin subclasses (empty → merge into parent)
DESIGN_PATTERNS: Template Method, Strategy, Factory when applicable

=SPEC=
NAMING: .call class methods; #method instance methods
CONTEXT: "when/with/without ..." never describe "edge cases"
NO_IMPL_TESTS: test observable behavior only via contexts
STUB_EXTERNAL: HTTP, queues, mailers, third-party SDKs, time, cache — NOT ActiveRecord relations. Chain-doubling a relation (double("Rel") with .where/.joins/.select returning self) silently absorbs invalid SQL, column typos, and bad joins. AR is internal to the app; its SQL validity is part of the contract under test, so stubbing an AR relation is not the same as stubbing an external collaborator.
DB_IN_UNIT: avoid DB in unit specs EXCEPT when the method emits raw SQL strings via .where("..."), .joins("..."), .select("..."), .group("..."), or Arel.sql(...); build > create; stubs > records for external collaborators only
RAW_SQL_COVERAGE: any method passing a raw SQL string to AR (.where("...sql..."), .joins("...sql..."), .select("...sql..."), .group("...sql..."), .order(Arel.sql(...))) MUST have at least one real-DB spec per conditional branch that emits a different SQL shape — a stubbed chain cannot validate column existence, join correctness, or cast compatibility; one of unit/request specs must exercise each branch (PG::UndefinedColumn, bad casts, missing joins only surface at the real DB)
:aggregate_failures ONLY when 2+ expects in one it block; NEVER add for single-expect blocks
SHORT it desc; detail in context names
option :records, optional: true for DI; no create inside it → let!/before
TYPE_CHECK: use Class directly in have_attributes (uses === case equality) — `attr: Numeric` not `attr: a_kind_of(Numeric)`
STRUCTURE: use have_attributes for object structure tests — `expect(obj).to have_attributes(a:, b:, c:)` not multiple `expect(obj.a)` calls; combine with a_hash_including for nested hashes
SETUP_EFFICIENCY: minimize records created + expensive operations — consolidate related contexts sharing same setup; merge edge cases into single context (e.g., "no holdings" + "deleted" + "zero quantity" → "when user has no valid holdings")
STUB_REUSE: use stubbed variables in expectations — `expect(obj).to have_attributes(stubbed_hash)` not duplicate hardcoded values

=SPEC_STYLE=
FILE: # frozen_string_literal: true | NEVER require "rails_helper" (auto-loaded) | RSpec.describe ClassName (constant,never string) | NEVER add type: (all types auto-inferred by directory)
SUBJECT: subject(:action) HTTP calls | subject(:result)/subject(:serializer) returns
LET: let! only must-exist-pre-test | Ruby 3.1 shorthand user: not user: user
EXPECTED: let(:expected_data) full hash → eq(expected_data) | super().merge/super().tap in nested
DESCRIBE: "GET #index" "POST create" "PATCH/PUT update" "DELETE destroy" | "#instance" ".class"
CONTEXT: always "when…"/"with…"/"without…"
SETUP: before{HTTP} when inspecting response | subject(:action) for side-effects | allow(S).to receive(:call).and_return + instance_double | around{Timecop.freeze(Time.current.round(6)){ex.run}} | create(:f,:trait) create_list attributes_for | helpers: login_admin api_header(user) parsed_body expect_success
EXPECT: .and chain related assertions | :aggregate_failures ONLY with 2+ expects (never single-expect) | change(M,:count).by(N) | have_enqueued_job(J).with | have_received(:call).with | it{is_expected.to eq(...)} | raise_error(E,"msg").and not_change | contain_exactly(have_attributes(...)) | perform_under(50).ms.warmup(2).times.sample(10).times
VALIDATE: API_TRIPLE=status+body+schema (have_http_status+eq(expected_data)+match_json_schema) | SERVICE_RESULT=be_a(ApplicationService::Result).and have_attributes(success?:true,errors:nil,data:Hash) | flash.to_h eq("success"=>I18n.t(...)) never hardcoded | I18n.t always | assigns(:var) backoffice | parsed_body API | match_json_schema("name")
REQUEST_BODY: match_json_schema validates STRUCTURE only and silently no-ops on empty collections (`data: []` bypasses every `items` rule). Do NOT add parsed_body shape assertions, BUT the populated (1)default example MUST assert `eq(expected_data)` on parsed_body — schema alone misses key typos (`:performance` vs `:performances`), shape drift, and value regressions
MATCH_SCHEMA_FILES: spec/support/api/schemas/** JSON schemas are the request-spec contract for match_json_schema — keep in lockstep with the serializer (update in the same commit on shape changes); dates use `format: date` / `format: date-time`, never bare `type: string` (same rule as OPENAPI DATES); `required: [...]` inside `items` only fires when the array is non-empty, so a populated (1)default is what actually exercises it
REQUEST_PARAMS: do NOT test every enum value (periods, currencies) in request specs — one example suffices; enum sanitization/validation belongs in unit specs (e.g., base_spec.rb)
HASH_FMT: column-align values with padding
COVERAGE: request→status/body(eq expected_data on populated happy path)/schema(match_json_schema)/template/flash/changes/jobs/delegation/redirects/filters/sorts/defaults/perf | serializer→full eq expected_data + context overrides | service→type+structure/success/failure/data/errors/edges(empty,zero,unsupported,boundary)

=SPEC_SCENARIOS=
PRINCIPLE: vary one dimension; happy first; context=business condition
REQUEST: list→(1)default(2)filters(3)sorts(4)empty(5)error | CRUD→valid/invalid per action: new→form, create→creates+redirect+flash / no-create+render+error, edit→form, update→updates+redirect / no-update+render, destroy→no-assoc / soft-delete / blocking | auth→happy/variation/failure | data_matrix→multi-state let! verify subsets
REQUEST_HAPPY_POPULATED: (1)default MUST produce a non-empty collection so schema `items` and body `eq(expected_data)` actually run — empty-wallet / empty-collection cases belong exclusively in (4)empty, never in (1)default
BRANCH_BY_FILTER: when a filter value dispatches to a different service, code path, or SQL shape (e.g., for_period: "1d" → live holdings + spot cache via hourly_period?, "all" → performance archive via long_term_data), each branch needs its own (1)default context with a populated response — NOT a single shared happy path across filter values. Enumerate dispatch branches from the implementation (CALCULATOR_BY_METHOD, hourly_period?, WALLET_HOURLY_PERIODS inclusion, etc.) and require one happy-path context per branch; request-level eq(expected_data) on one filter value does not cover the others
SERVICE: calculator→(1)zero(2)happy(3)each-zeroed(4)optional-omit(5)unrelated-preserved(6)idempotent | state→(1)create(2)update(3)invalid(4)side-effects(5)dirty(6)dep-failure(7)exclusion(8)already-target | auth→missing/valid/expired/blocked | query→empty/buy/sell/multi-empty/period/currency
EDGES: zero/nil/empty/too-many | buy-vs-sell | isolate-each-input | optional-omit→fallback | state-transitions | dep-failure→rollback | data-isolation(unrelated preserved) | idempotency | scope-filter(1w vs all) | dirty-state | exclusion-markers | user-state(blocked/locked→diff HTTP+i18n) | currency-variation(diff DB cols)

=SPEC_POST_RUN=
PROFILE: after running specs, review output for slow examples — flag any example >1s; suggest --profile flag if not already used; recommend let_it_be/create_list consolidation or stub replacements for DB-heavy slow specs
FLAKINESS: check for intermittent failures — re-run failing specs 2-3x to confirm determinism; flag time-dependent specs missing Timecop.freeze, order-dependent specs missing isolation, and specs relying on DB state from other examples; recommend :aggregate_failures or around { Timecop.freeze } fixes
FLAKY_PATTERNS: watch for rand/shuffle without seed, unfrozen time/date references (Time.now, Time.current, Date.today, DateTime.now, N.days.ago, N.hours.from_now) without Timecop.freeze/travel_to, shared mutable state (class vars, global config), missing DatabaseCleaner strategy, async jobs not drained in test — suggest concrete fixes
REPORT: summarize post-run analysis: (1) total time + slowest 5 examples (2) any flaky candidates with root cause hypothesis (3) actionable recommendations ordered by impact

=REVIEW=
CONTRACT: no skip; no early stop; partial=failure | BLOCKED: output missing+commands | file checklist [x] after reviewed | batch 10-25 files until REMAINING empty
SCOPE: read CLAUDE.md as law | base=develop(fetch if needed) | produce BASE/HEAD sha, FILE CHECKLIST, +/- stats
FORMAT: FILE CHECKLIST → PLAN(batch size/order/strategy) → per BATCH N: File/Type(source|config|docs|migration|tests|build/ci|generated|other)/Findings/Actions → DONE/REMAINING
FINDINGS: BREAKAGE_RISK | CORRECTNESS | SECURITY | PERFORMANCE | DATABASE(if applicable) | CONCURRENCY(if applicable) | MEMORY(if applicable) | MAINTAINABILITY | ERROR_HANDLING | TESTS | DOCS | CONVENTIONS | DEAD_CODE → concrete actions with file+line anchors
CHECKS: (1)correctness:contracts,validation,nil,errors,data,raw_sql_coverage(grep .where/.joins/.select/.group with string args in changed files → verify each branch has a real-DB spec; flag chain-doubled AR relations in spec/ as BREAKAGE_RISK; flag filter values that dispatch to distinct code paths without per-branch request specs) (2)perf:hot-paths,alloc,IO,batch (3)security:injection,authZ,secrets,PII (4)reliability:idempotency,races,limits (5)tests:behavior,assertions,coverage,speed (6)docs:behavior-changes,schema
FINAL: SUMMARY(must-fix/should-fix/nice-to-have) → TOP_WINS ranked → RISK_ASSESSMENT → VERIFICATION_COMMANDS exact+expected
NIL_SAFETY: Array.wrap(val).size<N handles nil | &. for chains | early return if assoc nil | .invert[key]&.to_sym guard

=ANTI_LAZY=
MUST complete; never summarize/skip → shrink batch + emit CONTINUATION BLOCK:
CONTINUE: NEXT_BATCH:<n> | REMAINING_FILES:[full explicit list, no globs] | DONE_FILES:[full explicit list] | OPEN_THREADS:[{id,description,evidence_needed}] | ARTIFACTS_CREATED:[{path,purpose,touched_in_batch}] | COMMANDS_RUN:["cmd1","cmd2"] | EVIDENCE_POINTERS:[{type:diff|routes|redocly|rspec|log,file,notes}]
RULES: explicit+exhaustive file lists always | "complete" only when REMAINING empty | shrink batch > truncate | track deferred evidence in OPEN_THREADS
