import WebKit

enum PasswordScriptProvider {
    static let name = "leafPasswordManager"

    static let captureSource = """
        (() => {
          if (window.__leafPasswordManagerInstalled) return;
          window.__leafPasswordManagerInstalled = true;
          window.__leafPasswordCaptureEnabled = false;
          const documentID = globalThis.crypto?.randomUUID?.() ||
            `${Date.now()}-${Math.random().toString(36).slice(2)}`;
          let announcedFieldState = '';
          let lastCaptureFingerprint = '';
          let lastPageState = '';
          let submittedInDocument = false;

          const isVisible = field => {
            if (!field || field.type === 'hidden' || field.hidden) return false;
            const style = getComputedStyle(field);
            return style.display !== 'none' &&
              style.visibility !== 'hidden' &&
              field.getClientRects().length > 0;
          };

          const firstUsableField = (root, selectors, excluding = null) => {
            const scope = root?.querySelectorAll ? root : document;
            for (const selector of selectors) {
              const fields = [...scope.querySelectorAll(selector)];
              const usable = fields.find(field =>
                field !== excluding &&
                !field.disabled && !field.readOnly && isVisible(field)
              );
              if (usable) return usable;
            }
            return null;
          };

          const passwordField = root => firstUsableField(root, [
            'input[type="password"][autocomplete="current-password"]',
            'input[type="password"][autocomplete="new-password"]',
            'input[type="password"]',
            'input[name*="pass" i]',
            'input[id*="pass" i]',
            'input[placeholder*="password" i]',
            'input[aria-label*="password" i]',
            'input[data-testid*="password" i]'
          ]);

          const newPasswordField = root => firstUsableField(root, [
            'input[type="password"][autocomplete="new-password"]',
            'input[autocomplete="new-password"]'
          ]);

          const passwordKind = field => {
            if (!field) return 'none';
            const autocomplete = (field.autocomplete ||
              field.getAttribute('autocomplete') || '').toLowerCase();
            return autocomplete.split(/\\s+/).includes('new-password')
              ? 'new'
              : 'current';
          };

          const isLikelyOneTimeCode = field => {
            if (!field) return false;
            const autocomplete = (field.autocomplete ||
              field.getAttribute('autocomplete') || '').toLowerCase();
            if (autocomplete.split(/\\s+/).includes('one-time-code')) return true;
            const descriptor = [
              field.name,
              field.id,
              field.placeholder,
              field.getAttribute('aria-label')
            ].filter(Boolean).join(' ');
            return /(^|\\b)(otp|totp|2fa|mfa|one[\\s_-]?time|verification[\\s_-]?code)(\\b|$)/i
              .test(descriptor);
          };

          const usernameField = root => {
            const password = passwordField(root);
            const specific = firstUsableField(root, [
              'input[autocomplete="username"]',
              'input[autocomplete="email"]',
              'input[type="email"]',
              'input[name*="user" i]',
              'input[name*="email" i]',
              'input[name*="login" i]',
              'input[name*="nim" i]',
              'input[id*="user" i]',
              'input[id*="email" i]',
              'input[id*="login" i]',
              'input[id*="nim" i]',
              'input[placeholder*="username" i]',
              'input[placeholder*="email" i]',
              'input[placeholder*="nim" i]'
            ], password);
            if (specific) return specific;

            const scope = root?.querySelectorAll ? root : document;
            return [...scope.querySelectorAll(
              'input[type="text"], input[type="tel"], input[type="number"], input:not([type])'
            )]
              .find(field =>
                field !== password &&
                !isLikelyOneTimeCode(field) &&
                !field.disabled &&
                !field.readOnly &&
                isVisible(field)
              ) || null;
          };

          const rememberedUsername = () => {
            try {
              return sessionStorage.getItem('__leafLastUsername') || '';
            } catch (_) {
              return '';
            }
          };

          const semanticUsernameValue = (root = document) => {
            const visible = usernameField(root) || usernameField(document);
            const visibleValue = visible?.value?.trim() || '';
            if (visibleValue) return visibleValue;

            const selectors = [
              'input[autocomplete="username"]',
              'input[name*="identifier" i]',
              'input[id*="identifier" i]',
              'input[name*="user" i]',
              'input[name*="email" i]',
              'input[name*="login" i]',
              'input[id*="user" i]',
              'input[id*="email" i]',
              'input[id*="login" i]'
            ];
            const initialScope = root?.querySelectorAll ? root : document;
            const scopes = initialScope === document
              ? [document]
              : [initialScope, document];
            for (const scope of scopes) {
              const password = passwordField(scope);
              for (const selector of selectors) {
                const field = [...scope.querySelectorAll(selector)].find(candidate =>
                  candidate !== password &&
                  !candidate.disabled &&
                  !isLikelyOneTimeCode(candidate) &&
                  !!candidate.value?.trim()
                );
                if (field) return field.value.trim();
              }
            }
            return '';
          };

          const rememberUsername = (root = document) => {
            const value = semanticUsernameValue(root);
            if (!value) return rememberedUsername();
            try { sessionStorage.setItem('__leafLastUsername', value); } catch (_) {}
            return value;
          };

          const fingerprint = value => {
            let hash = 2166136261;
            for (let index = 0; index < value.length; index += 1) {
              hash ^= value.charCodeAt(index);
              hash = Math.imul(hash, 16777619);
            }
            return String(hash >>> 0);
          };

          const captureCredentials = (root = document) => {
            if (!window.__leafPasswordCaptureEnabled) return false;
            const password =
              newPasswordField(root) ||
              newPasswordField(document) ||
              passwordField(root) ||
              passwordField(document);
            if (!password?.value) return false;

            const username = rememberUsername(root) || rememberedUsername();
            if (!username) return false;

            const currentFingerprint = fingerprint(
              `${location.hostname}\n${username}\n${password.value}`
            );
            if (currentFingerprint === lastCaptureFingerprint) return false;
            lastCaptureFingerprint = currentFingerprint;

            window.webkit.messageHandlers.leafPasswordManager.postMessage({
              type: 'submitted',
              host: location.hostname,
              username,
              password: password.value,
              passwordKind: passwordKind(password),
              documentID,
              path: `${location.pathname}${location.search}`
            });
            submittedInDocument = true;
            setTimeout(() => postPageState('delayed'), 900);
            return true;
          };

          const isLoginAction = element => {
            if (!element) return false;
            const type = (element.getAttribute('type') || '').toLowerCase();
            if (type === 'submit') return true;
            const descriptor = [
              element.id,
              element.getAttribute('name'),
              element.getAttribute('aria-label'),
              element.textContent
            ].filter(Boolean).join(' ').toLowerCase();
            return /(sign[\\s-]?in|log[\\s-]?in|next|continue|submit|verify|masuk|lanjut|berikutnya)/i
              .test(descriptor);
          };

          const announcePasswordField = (force = false) => {
            const username = usernameField(document);
            const password = passwordField(document);
            if (!username && !password) return;
            const usernameValue = semanticUsernameValue(document) || rememberedUsername();
            const state = `${!!username}:${!!password}:${usernameValue}`;
            if (!force && state === announcedFieldState) return;
            announcedFieldState = state;
            window.webkit.messageHandlers.leafPasswordManager.postMessage({
              type: 'fillableForm',
              host: location.hostname,
              username: usernameValue,
              passwordKind: passwordKind(password),
              documentID
            });
          };

          const postPageState = (reason, force = false) => {
            const password = passwordField(document);
            const username = usernameField(document);
            const state = [
              documentID,
              location.href,
              !!username,
              !!password,
              passwordKind(password)
            ].join(':');
            if (!force && state === lastPageState) return;
            lastPageState = state;
            window.webkit.messageHandlers.leafPasswordManager.postMessage({
              type: 'pageState',
              host: location.hostname,
              documentID,
              reason,
              hasUsername: !!username,
              hasPassword: !!password,
              passwordKind: passwordKind(password),
              path: `${location.pathname}${location.search}`
            });
          };

          window.__leafPasswordManagerRefresh = () => announcePasswordField(true);

          document.addEventListener('submit', event => {
            const form = event.target;
            if (!(form instanceof HTMLFormElement)) return;
            rememberUsername(form);
            captureCredentials(form);
          }, true);

          document.addEventListener('input', event => {
            const field = event.target;
            if (!(field instanceof HTMLInputElement)) return;
            if (field.type === 'email' ||
                field.autocomplete === 'username' ||
                /user|email/i.test(`${field.name} ${field.id}`) ||
                field === usernameField(document)) {
              rememberUsername(field.form || document);
              announcePasswordField(true);
            }
          }, true);

          document.addEventListener('click', event => {
            const action = event.target?.closest?.(
              'button, input[type="submit"], input[type="button"], [role="button"]'
            );
            if (!isLoginAction(action)) return;
            const root = action.closest?.('form') || document;
            rememberUsername(root);
            captureCredentials(root);
          }, true);

          document.addEventListener('keydown', event => {
            if (event.key !== 'Enter') return;
            const root = event.target?.form || document;
            rememberUsername(root);
            captureCredentials(root);
          }, true);

          window.addEventListener('pagehide', () => captureCredentials(document), true);

          let mutationScheduled = false;
          const observer = new MutationObserver(() => {
            if (mutationScheduled) return;
            mutationScheduled = true;
            requestAnimationFrame(() => {
              mutationScheduled = false;
              announcePasswordField();
              if (submittedInDocument) postPageState('mutation');
            });
          });
          const beginObserving = () => {
            if (!document.documentElement) return;
            observer.observe(document.documentElement, { childList: true, subtree: true });
            announcePasswordField();
            postPageState('ready', true);
          };

          for (const method of ['pushState', 'replaceState']) {
            const original = history[method];
            history[method] = function(...args) {
              const result = original.apply(this, args);
              requestAnimationFrame(() => postPageState('history', true));
              return result;
            };
          }
          window.addEventListener('popstate', () => postPageState('history', true));

          if (document.documentElement) beginObserving();
          else document.addEventListener('DOMContentLoaded', beginObserving, { once: true });
        })();
        """

    static let script = WKUserScript(
        source: captureSource,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    static func autofillScript(
        username: String,
        password: String,
        replacingExistingValues: Bool = false
    ) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: [
                "username": username,
                "password": password,
                "replacingExistingValues": replacingExistingValues
            ]
        ), let payload = String(data: data, encoding: .utf8) else { return nil }
        return """
        (() => {
          const credential = \(payload);
          const password = [
            document.querySelector('input[type="password"][autocomplete="current-password"]'),
            document.querySelector('input[type="password"]'),
            document.querySelector('input[name*="pass" i]'),
            document.querySelector('input[id*="pass" i]'),
            document.querySelector('input[placeholder*="password" i]'),
            document.querySelector('input[aria-label*="password" i]'),
            document.querySelector('input[data-testid*="password" i]')
          ].find(field => {
            if (!field || field.disabled || field.readOnly ||
                field.hidden || field.getClientRects().length === 0) return false;
            const autocomplete = (field.autocomplete ||
              field.getAttribute('autocomplete') || '').toLowerCase();
            return !autocomplete.split(/\\s+/).includes('new-password');
          }) || null;
          const username = [
            document.querySelector('input[autocomplete="username"]'),
            document.querySelector('input[autocomplete="email"]'),
            document.querySelector('input[type="email"]'),
            document.querySelector('input[name*="user" i]'),
            document.querySelector('input[name*="email" i]'),
            document.querySelector('input[name*="login" i]'),
            document.querySelector('input[name*="nim" i]'),
            document.querySelector('input[id*="user" i]'),
            document.querySelector('input[id*="email" i]'),
            document.querySelector('input[id*="login" i]'),
            document.querySelector('input[id*="nim" i]'),
            document.querySelector('input[placeholder*="username" i]'),
            document.querySelector('input[placeholder*="email" i]'),
            document.querySelector('input[placeholder*="nim" i]'),
            document.querySelector('input[type="text"]'),
            document.querySelector('input[type="tel"]'),
            document.querySelector('input[type="number"]')
          ].find(field =>
            field &&
            field !== password &&
            !field.disabled &&
            !field.readOnly &&
            !field.hidden &&
            field.getClientRects().length > 0
          ) || null;
          const setValue = (field, value) => {
            if (!field || (!credential.replacingExistingValues && field.value)) return;
            const setter = Object.getOwnPropertyDescriptor(
              Object.getPrototypeOf(field), 'value'
            )?.set;
            setter ? setter.call(field, value) : field.value = value;
            field.dispatchEvent(new Event('input', { bubbles: true }));
            field.dispatchEvent(new Event('change', { bubbles: true }));
          };
          setValue(username, credential.username);
          setValue(password, credential.password);
          return !!username || !!password;
        })();
        """
    }
}
