import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TicTacToeCommon
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  struct ViewState: Equatable {
    var alertData: AlertData?
    var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    var password: String
    var isTwoFactorActive: Bool
  }

  enum ViewAction {
    case alertDismissed
    case emailChanged(String)
    case loginButtonTapped
    case passwordChanged(String)
    case twoFactorDismissed
  }

  let store: Store<LoginState, LoginAction>

  public init(store: Store<LoginState, LoginAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: \.view, action: LoginAction.view)) { viewStore in
      VStack {
        Form {
          Section(
            header: Text(
              """
              To login use any email and "password" for the password. If your email contains the \
              characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
              use "1234" for the code.
              """
            )
          ) { EmptyView() }

          Section(header: Text("Email")) {
            TextField(
              "blob@pointfree.co",
              text: viewStore.binding(get: \.email, send: ViewAction.emailChanged)
            )
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
          }
          Section(header: Text("Password")) {
            SecureField(
              "••••••••",
              text: viewStore.binding(get: \.password, send: ViewAction.passwordChanged)
            )
          }
          Section {
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(state: \.twoFactor, action: LoginAction.twoFactor),
                then: TwoFactorView.init(store:)
              ),
              isActive: viewStore.binding(
                get: \.isTwoFactorActive,
                send: { $0 ? .loginButtonTapped : .twoFactorDismissed }
              )
            ) {
              Text("Log in")

              if viewStore.isActivityIndicatorVisible {
                ActivityIndicator()
              }
            }
            .disabled(viewStore.isLoginButtonDisabled)
          }
        }
        .disabled(viewStore.isFormDisabled)
      }
      .navigationBarTitle("Login")
      // NB: This is necessary to clear the bar items from the game.
      .navigationBarItems(trailing: EmptyView())
      .alert(
        item: viewStore.binding(get: \.alertData, send: .alertDismissed)
      ) { alertData in
        Alert(title: Text(alertData.title))
      }
    }
  }
}

extension LoginState {
  var view: LoginView.ViewState {
    LoginView.ViewState(
      alertData: self.alertData,
      email: self.email,
      isActivityIndicatorVisible: self.isLoginRequestInFlight,
      isFormDisabled: self.isLoginRequestInFlight,
      isLoginButtonDisabled: !self.isFormValid,
      password: self.password,
      isTwoFactorActive: self.twoFactor != nil
    )
  }
}

extension LoginAction {
  static func view(_ localAction: LoginView.ViewAction) -> Self {
    switch localAction {
    case .alertDismissed:
      return .alertDismissed
    case .twoFactorDismissed:
      return .twoFactorDismissed
    case let .emailChanged(email):
      return .emailChanged(email)
    case .loginButtonTapped:
      return .loginButtonTapped
    case let .passwordChanged(password):
      return .passwordChanged(password)
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoginView(
        store: Store(
          initialState: LoginState(),
          reducer: loginFeatureReducer,
          environment: LoginEnvironment(
            authenticationClient: AuthenticationClient(
              login: { _ in Effect(value: .init(token: "deadbeef", twoFactorRequired: false)) },
              twoFactor: { _ in Effect(value: .init(token: "deadbeef", twoFactorRequired: false)) }
            ),
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
