//
//  AuthStartView.swift
//  BonApp
//
//  Created by Marcin on 26/10/2025.
//

import SwiftUI

struct AuthStartView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Witaj w BonApp 👋")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Zaloguj się lub załóż konto, aby korzystać ze wszystkich funkcji aplikacji.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Zaloguj się")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    NavigationLink {
                        RegistrationView()
                    } label: {
                        Text("Zarejestruj się")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Logowanie")
        }
    }
}

#Preview {
    AuthStartView()
}
