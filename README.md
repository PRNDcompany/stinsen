<p align="center">
  <img src="./Images/wordmark.svg" alt="Stinsen">
</p>

[![Language](https://img.shields.io/static/v1.svg?label=language&message=Swift%205.9&color=FA7343&logo=swift&style=flat-square)](https://swift.org)
[![Platform](https://img.shields.io/static/v1.svg?label=platform&message=iOS%2015%2B&logo=apple&style=flat-square)](https://apple.com)
[![License](https://img.shields.io/cocoapods/l/Crossroad.svg?style=flat-square)](https://github.com/rundfunk47/stinsen/blob/main/LICENSE)

An implementation of the Coordinator pattern where **UIKit owns navigation and SwiftUI is
a first-class citizen on top of it**. Screens can be `UIViewController`s or SwiftUI
views, in the same stack, and the app can be hosted from either runtime.

> **This is a fork.** Upstream [rundfunk47/stinsen](https://github.com/rundfunk47/stinsen)
> is 100% SwiftUI and cross-platform. This fork moved the transition engine to UIKit and
> is iOS-only. See [Differences from upstream](#differences-from-upstream-) before
> migrating.

# Why? 🤔

Routing is hard to do elegantly in a large app: `NavigationLink` lives in the view layer,
there is no clear concept of a flow or a route, and views end up knowing about every other
view they can reach. The Coordinator pattern — presented to the iOS community by Soroush
Khanlou at NSSpain in 2015 — moves that responsibility up, out of the view.

The specific bet this fork makes is about *who owns the navigation stack*. UIKit already
knows the order of the screens on screen, owns their lifetimes, and provides
`popToViewController(_:)`. A coordinator that keeps its own parallel array of screens has
a second opinion about all three, and the two disagree whenever anything happens that the
coordinator did not initiate — a back swipe, a sheet dragged down, a system flow, or any
code outside the coordinator closing a view controller.

So the stack is not kept. It is read back from UIKit on every operation. What the
coordinator retains is the one thing UIKit cannot know: **which route produced a screen**.

# What is a Coordinator? 🤷🏽‍♂️

Normally the view has to add other views to the navigation stack itself. That couples the
views together — a view must know in advance everything it can navigate to — and puts it
in violation of the single-responsibility principle. A coordinator takes that job.

# Getting started 👩🏼‍🏫

## Defining a coordinator

```swift
final class UnauthenticatedCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack(initial: \UnauthenticatedCoordinator.start)

    @Root var start = makeStart
    @Route(.modal) var forgotPassword = makeForgotPassword
    @Route(.push) var registration = makeRegistration

    func makeRegistration() -> RegistrationCoordinator {
        RegistrationCoordinator()
    }

    @ViewBuilder func makeForgotPassword() -> some View {
        ForgotPasswordScreen()
    }

    @ViewBuilder func makeStart() -> some View {
        LoginScreen()
    }
}
```

`@Route` declares a route and the transition it performs; the value on the right is the
factory run when routing, returning either a view or another coordinator. `@Root` is a
route with no transition — the coordinator's first screen.

Two `Coordinatable` protocols cover the standard cases:

* `NavigationCoordinatable` — navigational flows.
* `TabCoordinatable` — tabs.

Plus two coordinators you can use directly: `ViewWrapperCoordinator` wraps a coordinator's
view in another view, and `NavigationViewCoordinator` is a subclass of it that wraps in a
`NavigationView`.

## Showing the coordinator

From UIKit:

```swift
// SceneDelegate
window.rootViewController = MainCoordinator().viewController()

// or, when the coordinator's routes include .push and nothing else provides navigation:
window.rootViewController = MainCoordinator().navigationController()
```

`viewController()` returns a UIKit container that is also the coordinator's navigation
anchor. Its active root is installed as a direct child: a SwiftUI root crosses through one
`UIHostingController`, while a `UIViewController` root stays the app's original controller.
No SwiftUI render or layout pass is required to discover the UIKit anchor.

SwiftUI-to-SwiftUI root changes stay inside that one hosting controller, retaining their
SwiftUI transaction and `AnyTransition`. A switch that crosses into or out of a native
view-controller root is a UIKit boundary and uses the container transition instead.

From SwiftUI:

```swift
struct StinsenApp: App {
    var body: some Scene {
        WindowGroup {
            MainCoordinator().view()
        }
    }
}
```

Both are supported and exercised by the same UI test suite, run twice. Stinsen can power
your whole app or part of it; ordinary `NavigationLink`s and sheets still work inside
views it manages.

The SwiftUI entry remains a different rendering path on purpose. `view()` composes
SwiftUI roots in the surrounding SwiftUI tree, so transactions, environment and size
animations are not routed through an extra hosting controller. A coordinator-local
background controller supplies its UIKit navigation anchor; this also works when the
surrounding `UIHostingController` was built by the app rather than by Stinsen.

## Navigating

Routing happens on the coordinator. Give the view what it needs to *ask* — a closure, or
the coordinator itself — rather than making the view do the navigating:

```swift
struct TodosScreen: View {
    let createTodoTapped: () -> Void

    var body: some View {
        List { /* ... */ }
            .navigationBarItems(
                trailing: Button(
                    action: createTodoTapped,
                    label: { Image(systemName: "doc.badge.plus") }
                )
            )
    }
}

// in the coordinator's factory
@ViewBuilder func makeTodos() -> some View {
    TodosScreen(createTodoTapped: { [weak self] in self?.route(to: \.createTodo) })
}
```

> **Why not an `@EnvironmentObject` router?** Because it cannot reach: each screen is its
> own `UIHostingController`, and the SwiftUI environment does not cross that boundary.
> Upstream's `RouterStore` was a global registry working around exactly this, and it is
> gone. A view that receives what it needs is also the coordinator pattern working as
> intended.

Routing without declaring a route first — the recommended style for new code — builds the
screen at the call site:

```swift
coordinator.route(.push, to: ProductView(id: 42))
coordinator.route(.modal, to: FilterViewController())        // a UIViewController
coordinator.route(.push, to: ReviewListView(), id: "reviews") // named, so you can return to it
coordinator.route(.modal, to: CheckoutCoordinator())
```

Operations on a `NavigationCoordinatable`:

| | |
|---|---|
| `route(to:)` / `route(_:to:)` | Open a screen. |
| `popLast()` | Close the top screen. Push or modal — the same call for both. |
| `popToRoot()` | Close everything. Crosses presentation boundaries. |
| `popTo(id:)` | Return to a screen opened with `route(_:to:id:)`. The **nearest** match. |
| `focusFirst(_:)` | Find the **first** screen matching a declared route and close everything above it. |
| `root(_:)` | Change the root. Closes the screens the outgoing root had open. |
| `hasRoot(_:)` | The active root's child, if that route is the one rooted. |
| `dismissCoordinator()` | Ask the parent to close this whole coordinator. |

Because routes are key paths these are type-safe: if there is a route from _A_ to _B_ and
from _B_ to _C_, a chain from _A_ straight to _C_ will not compile.

# UIKit and SwiftUI 🧩

Any screen can be either. A stack can alternate freely.

```swift
coordinator.route(.push, to: ProductViewController(id: 42))   // UIKit
coordinator.route(.push, to: ReviewsView())                   // SwiftUI
coordinator.popToRoot()                                       // closes both
```

A view controller you supply is presented **as it is** — not wrapped, not subclassed, still
the object you are holding a reference to — and gets the same lifecycle callbacks, the same
place in `popLast()` / `popToRoot()` / `popTo(id:)`, and the same behaviour when something
outside the coordinator closes it.

One thing *is* added: an invisible child view controller, which is how appearance callbacks
for a screen the library did not build are observed at all (UIKit forwards them to
children). It has a zero-sized hidden view, takes no touches, and is the only alternative to
swizzling your class. It shows up in `children`, so code that reassigns containment can
remove it by accident — that is noticed and repaired, with a DEBUG log saying so. Navigation
never depends on it; only lifecycle reporting does.

**One known consequence.** Adding it loads your view controller's view, which means
`viewDidLoad` runs a step earlier than plain UIKit would run it — before the screen has been
pushed. Anything in `viewDidLoad` that reads the surroundings sees them empty:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    navigationController?.setNavigationBarHidden(true, animated: false)  // nil here
}
```

Move that to `viewWillAppear`, which runs at the normal time and is where a navigation bar
is usually configured anyway. `navigationItem` is unaffected — it belongs to your screen, not
to the navigation controller — and so is everything that does not reach outside itself.

That includes a `UIHostingController` you built yourself, which is how SwiftUI content
gets an environment across a screen boundary:

```swift
let screen = UIHostingController(
    rootView: ProductView(id: 42).environmentObject(theme)
)
coordinator.route(.push, to: screen)
```

Roots and tabs work the same way:

```swift
final class MainCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack(initial: \MainCoordinator.login)

    @Root var login = makeLoginViewController      // -> UIViewController
    @Root var home  = makeHomeScreen               // -> some View
}

final class AppTabCoordinator: TabCoordinatable {
    let child = TabChild(startingItems: [\AppTabCoordinator.todos])

    // Declared for both hosts. A SwiftUI view cannot be turned into a UITabBarItem, so
    // a coordinator that wants to be hostable either way says both.
    @Route(tabItem: makeTodosTab, tabBarItem: makeTodosBarItem)
    var todos = makeTodos
}

appTabCoordinator.viewController()   // a real UITabBarController
appTabCoordinator.view()             // a SwiftUI TabView
```

That choice follows the runtime doing the presenting, not just the entry point. Routing to a
coordinator with `.push`, `.modal` or `.fullScreen` puts up *its* view controller — so a tab
coordinator opened as a screen is a real `UITabBarController` there too, with tab bar items
to configure and a delegate to hook, rather than a `TabView` hosted inside it.

# Lifecycle 🔄

Coordinators can opt in to hearing about their screens. Every requirement has a no-op
default, so conforming costs nothing.

```swift
extension TodosCoordinator: CoordinatorLifecycleAware {
    func screenDidAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {
        analytics.track(screen: route)
    }

    func screenDidDisappear(_ route: RouteKey, viewController: UIViewController,
                            reason: ScreenDisappearReason) {
        guard reason.isClosed else { return }   // .covered means it is still on the stack
        cancelInFlightRequests(for: viewController)
    }
}
```

`viewController` is passed alongside `route` because the route alone cannot say *which*
screen this is — drilling from one product detail into another gives both the same route.
The view controller is the occurrence identity.

`ScreenDisappearReason` is `.popped`, `.dismissed`, `.covered` or `.detached`. Use
`isClosed` rather than enumerating: which of the three "closed" reasons you get depends on
where the screen was. The top screen reports `.popped` or `.dismissed`; one that was
already covered reports `.detached`, because UIKit sent its disappearance when it was
covered and sends nothing more when it is finally removed.

## What is guaranteed

| | |
|---|---|
| `onDismiss` on `route(_:to:onDismiss:)` | **Exactly once**, whichever path closed the screen. The coordinator runs it when it drops the screen rather than waiting to be told. |
| `CoordinatorLifecycleAware` | **Observations.** Reported when UIKit says so, and they inherit UIKit's silences. |
| The stack matching what is on screen | Membership is derived from UIKit on every operation, so it is correct even after a close the coordinator did not initiate. |

`onDismiss` says *the coordinator is no longer showing this screen*, which is not quite the
same as *the animation has finished*. It runs synchronously when the screen is dropped:
immediately for a close the coordinator performed, and on the next operation or lifecycle
signal for one it did not — which is as soon as it can be, since nothing announces a screen
that was already hidden when something else removed it. It also runs for a screen that was
recorded but never got as far as being presented, because that screen is equally not being
shown. For "the transition is over", use the completion on `popLast(_:)` / `popToRoot(_:)`.

Lifecycle is silent for a screen inside a container that does not forward appearance
callbacks — which every UIKit container does, `UITabBarController` and
`UINavigationController` included. A DEBUG log says so when it happens. Navigation is
unaffected: liveness comes from UIKit, not from the lifecycle callbacks — a screen that
went up without announcing itself is still recognised as being up, and still closes.

# Advanced usage 👩🏾‍🔬

## Custom presentations

`.push`, `.modal` and `.fullScreen` are built in. Anything else is three closures:

```swift
static let overlay = AnyPresentationType(
    make: { content, dismiss in HeroViewController(rootView: content, onDismiss: dismiss) },
    present: { parent, vc in parent.addChild(vc); /* ... */ },
    dismiss: { vc in /* reverse the hero animation, then remove */ }
)

coordinator.route(Self.overlay, to: ProductView(id: 42))
```

Teardown always goes through your `dismiss` closure, so a reverse animation or your own
cleanup is never skipped — including when your presentation declares a `kind:` of `.push`
or `.modal`. That declaration is read for diagnostics only; whether a screen can be taken
down through UIKit directly is decided by who built the presentation, not by what it calls
itself. A custom presentation is typed to whatever `make` returns and can only present that
type — routing another kind of view controller through it trips an assertion saying so.

Your `present` closure may take its time. A screen is not assumed to be on screen until it
actually is, so a presentation that attaches from a completion handler, after a layout pass,
or into containment of its own is not mistaken for one that failed — and once it is up it is
tracked like any other screen, whether or not anything announced its arrival.

## Customizing

`NavigationCoordinatable` and `TabCoordinatable` have a `customize` function applied to
the coordinator's root view:

```swift
@ViewBuilder func customize(_ view: AnyView) -> some View {
    view.onReceive(Services.shared.$authentication) { authentication in
        switch authentication {
        case .authenticated:   self.root(\.authenticated)
        case .unauthenticated: self.root(\.unauthenticated)
        }
    }
}
```

It is a SwiftUI view modifier, so it customizes what SwiftUI renders. The UIKit half is
`configure`, which hands you the view controller the library built to stand for the
coordinator:

```swift
func configure(_ viewController: UIViewController) {
    viewController.tabBarItem = UITabBarItem(title: "Todos", image: UIImage(systemName: "list.bullet"), tag: 0)
    viewController.isModalInPresentation = true
}
```

That is the only way to reach the things that are not view state — `title`, `tabBarItem`,
`navigationItem`, `modalPresentationStyle` — and the only hook a `TabCoordinatable` hosted as
a real `UITabBarController` has, since there is no SwiftUI view there to modify.

| | |
|---|---|
| When | Once per view controller the library builds, before anything presents it. `viewController()` is a factory, so asking twice configures twice. |
| Where it does **not** run | The SwiftUI path (`view()`) — `customize` is the hook there — and screens whose container is built by your own presentation, which is typed to its own container. |
| Precedence | A route declaration outranks it: `.fullScreen` re-asserts its presentation style, and a tab declared with `tabBarItem:` overwrites one set here. `.modal` does not touch presentation style, so choosing `.formSheet` in `configure` works. |
| If you implement `viewController()` yourself | Yours wins, and nothing calls `configure` for you. Call it yourself. |

The two are counterparts, not equivalents. Anything `customize` does to the SwiftUI
*environment* has no UIKit expression: an `.environmentObject` injected around a `TabView`
reaches its tabs, while one injected around a `UITabBarController` would reach nothing,
because each tab is hosted separately. Inject those in the tabs themselves.

Keep navigation state subscriptions in the coordinator (or another model it owns), not in
`customize`. A modifier such as `onReceive` exists only while that SwiftUI subtree is being
rendered; a UIKit entry may be showing a native root or child coordinator with no parent
SwiftUI subtree at all. Likewise, forward UIKit scene URLs to the coordinator from
`scene(_:openURLContexts:)`; `onOpenURL` remains the SwiftUI entry hook.

## Chaining

Most operations return a coordinator, so they compose:

```swift
authenticatedCoordinator
    .focusFirst(\.todos)     // make the todos tab active
    .child                   // the NavigationViewCoordinator's child
    .popToRoot()
    .route(to: \.todo, todo.id)
```

## Deep linking

```swift
@ViewBuilder func customize(_ view: AnyView) -> some View {
    view.onOpenURL { url in
        // Coordinator routes are erased to AnyCoordinator so factories can return
        // `some Coordinatable` — unwrap to get back to your own API.
        guard let coordinator = self.hasRoot(\.authenticated)?
            .unwrap(AuthenticatedCoordinator.self) else { return }

        if case .todo(let id) = try? DeepLink(url: url, todosStore: coordinator.todosStore) {
            coordinator.focusFirst(\.todos).child.route(to: \.todo, id)
        }
    }
}
```

Routing before anything has rendered is fine — screens recorded with nowhere to go yet go
up when there is somewhere.

# Examples 📱

<img src="./Images/stinsenapp-ios.gif" alt="Stinsen Sample App">

Clone the repo and run _StinsenApp_ in `Examples/App`. Its **Testbed** tab is where the
behaviour is exercised: mixed UIKit/SwiftUI chains, back-to-back navigation, custom
presentations, embedded coordinators, UIKit tabs, and every lifecycle reason. The UI tests
in `Examples/App/UITests` drive it.

Run the suite against both entry points:

```bash
# SwiftUI entry
xcodebuild test -scheme 'StinsenApp (iOS)' -destination 'platform=iOS Simulator,name=iPhone 16'

# UIKit entry — same tests, booted from a SceneDelegate
xcodebuild test -scheme 'StinsenApp (iOS)' -destination 'platform=iOS Simulator,name=iPhone 16' \
    TEST_RUNNER_STINSEN_UIKIT_ENTRY=1
```

# Differences from upstream 🔀

| | Upstream | This fork |
|---|---|---|
| Transitions | SwiftUI `NavigationLink(isActive:)`, `.sheet` | UIKit `push` / `present` |
| Platforms | iOS, tvOS, watchOS, macOS | iOS 15+ |
| Screens | SwiftUI views | SwiftUI views **or** `UIViewController`s |
| Entry | `view()` | `view()`, `viewController()`, `navigationController()` |
| Routers | `@EnvironmentObject` router, `RouterStore`, `@RouterObject` | Removed — the environment does not cross a hosting controller boundary |
| Lifecycle | — | `CoordinatorLifecycleAware` with reasons |
| Duplicate pushes | Same route twice in a row was dropped | Not deduplicated, as in UIKit — debouncing is the app's job |

**Migrating:** replace router injection with closures or constructor injection, and
`hasRoot(_:)` now returns `AnyCoordinator` — call `.unwrap(MyCoordinator.self)`.

# Not supported 🚫

* **SwiftUI environment across screens.** Each screen is its own hosting controller. Build
  the `UIHostingController` yourself and inject there, or pass values in.
* **Sharing one `UINavigationController` between sibling coordinators.** Parent → child
  sharing is supported and intended; siblings are ambiguous about which stack a push means.
* **State restoration across process death.** Deep links are replayed as routes instead.
* **`NavigationStack(path:)` interop.** Do not mix.
* **Non-iOS platforms.**

# Installation 💾

## SPM

`File / Add Package Dependencies…`, then this repository's URL.

## CocoaPods

```ruby
# Podfile
use_frameworks!

target 'YOUR_TARGET_NAME' do
    pod 'Stinsen'
end
```

# Who are responsible? 🙋🏿‍♂️

Upstream _Stinsen_ was created at Byva and is maintained by
[@rundfunk47](https://github.com/rundfunk47/). This fork is maintained separately.

# Why the name "Stinsen"? 🚂

_Stins_ is short in Swedish for "Station Master", and _Stinsen_ is the definite article,
"The Station Master". Colloquially the term mostly referred to the Train Dispatcher, who
is responsible for routing the trains. The logo is based on a wooden statue of a _stins_
near the train station in Linköping, Sweden.

# License 📃

_Stinsen_ is released under an MIT license. See LICENCE for more information.
