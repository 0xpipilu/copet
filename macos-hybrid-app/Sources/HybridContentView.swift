import SwiftUI
import WebKit
import AppKit
import Combine

struct HybridContentView: View {
    @EnvironmentObject private var store: CodpetHybridStore
    @State private var isShowingSettings = false
    private let syncTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let pageURL = store.webStoreURL(), let repoRoot = store.repoRoot {
                    CodpetWebStoreView(pageURL: pageURL, readAccessRoot: repoRoot)
                } else {
                    ContentUnavailableView(
                        "没有找到 cod.pet 仓库",
                        systemImage: "folder.badge.questionmark",
                        description: Text("请在设置中配置正确的仓库路径。")
                    )
                }
                
                // Top-right floating settings button
                Button {
                    isShowingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary.opacity(0.75))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(16)
                
                // Bottom floating status toast
                if let statusMessage = store.statusMessage, !statusMessage.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(statusMessage)
                                .font(.subheadline.weight(.medium))
                            Button(action: {
                                store.statusMessage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(width: 1080, height: 720)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                HybridSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                isShowingSettings = false
                            }
                        }
                    }
            }
            .frame(width: 500, height: 480)
        }
        .onReceive(syncTimer) { _ in
            store.syncFromCodex()
        }
    }
}

struct HybridSettingsView: View {
    @EnvironmentObject private var store: CodpetHybridStore
    
    var body: some View {
        Form {
            Section("工作区") {
                LabeledContent("仓库目录") {
                    Text(store.repoRoot?.path ?? "Not found")
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Codex Pet 目录") {
                    Text(store.petsDir.path)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                HStack(spacing: 12) {
                    Button("打开仓库目录") {
                        store.revealRepositoryRoot()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("打开 Codex Pet 目录") {
                        store.revealCodexPetsFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("刷新全部状态") {
                        store.refreshAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Section("应用方式") {
                Picker("选择 Pet 后", selection: $store.applyMode) {
                    ForEach(CodexApplyMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(store.applyMode.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("连接诊断") {
                Text("先用这里测试 Codex 当前窗口是否允许脚本注入；如果这一步不通，应用 pet 也不会即时生效。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button("测试 Codex 应用桥") {
                        store.diagnoseCodexBridge()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("打开 Codex") {
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.activates = true
                        NSWorkspace.shared.openApplication(
                            at: URL(fileURLWithPath: "/Applications/Codex.app"),
                            configuration: configuration,
                            completionHandler: nil
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("说明") {
                Text("这版 hybrid app 保留了现有 `cod.pet` 的展示体验，同时把本地安装、删除、应用这些动作接回了 macOS 原生层。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("当前版本会定时同步 `~/.codex/config.toml` 和本地 Pet 目录，所以你在 Codex 里手动切换后，这里也会很快反映出来。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("如果你选择“尝试即时刷新”，app 会优先请求 Codex 自己应用 `selected-avatar-id`。第一次使用时，macOS 可能会要求你允许这个 app 控制 Codex。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 12)
        .navigationTitle("设置")
    }
}

struct CodpetWebStoreView: NSViewRepresentable {
    @EnvironmentObject private var store: CodpetHybridStore
    let pageURL: URL
    let readAccessRoot: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "codpetNative")
        contentController.addUserScript(
            WKUserScript(
                source: injectedBridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadFileURL(pageURL, allowingReadAccessTo: readAccessRoot)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.store = store
        context.coordinator.syncInstalledState(in: webView)
    }
    
    private var injectedBridgeScript: String {
        """
        (function() {
          if (window.__codpetNativeInjected) return;
          window.__codpetNativeInjected = true;

          const downloadIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>`;
          const trashIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>`;

          const style = document.createElement("style");
          style.textContent = `
            body {
              user-select: none;
            }
            .header, .footer {
              display: none !important;
            }
            main.shell {
              max-width: 100% !important;
              width: 100% !important;
              padding: 0 !important;
              margin: 0 !important;
            }
            .gallery {
              border-left: none !important;
              min-height: calc(100vh - 16px) !important;
            }
            .tile-dl {
              display: none !important;
            }
            
            /* Action Button replacing Pet Name on hover */
            .tile-name {
              display: block !important;
            }
            .tile:hover .tile-name {
              display: none !important;
            }
            .app-action-btn {
              display: none;
              align-items: center;
              justify-content: center;
              width: 24px;
              height: 24px;
              border: none;
              background: transparent;
              color: rgba(0, 0, 0, 0.4);
              cursor: pointer;
              transition: color 100ms;
              box-shadow: none !important;
              position: static !important;
              transform: none !important;
            }
            .tile:hover .app-action-btn {
              display: inline-flex !important;
            }
            .app-action-btn:hover {
              color: #000 !important;
              background: transparent !important;
            }
            .app-action-btn.delete-btn {
              color: #ff3b30 !important;
            }
            .app-action-btn.delete-btn:hover {
              color: #d32f2f !important;
            }
            
            /* Installed: colorful static image */
            .tile.native-installed:not(.playing) .sprite-static-gray {
              filter: grayscale(0%) !important;
              opacity: 1 !important;
            }
            .tile.native-installed:not(.playing) .sprite-static-color {
              clip-path: inset(0% 0 0 0) !important;
            }
            
            /* NEW badge styling */
            .tile.is-new-pet::before {
              content: "NEW";
              position: absolute;
              top: 8px;
              left: 8px;
              background: #ff9500;
              color: #fff;
              font-size: 9px;
              font-weight: 700;
              padding: 2px 6px;
              border-radius: 99px;
              z-index: 5;
              text-transform: uppercase;
              letter-spacing: 0.05em;
              transition: opacity 300ms ease;
            }
            .tile.native-active.is-new-pet::before {
              display: none !important;
            }
          `;
          document.documentElement.appendChild(style);

          // NEW badge local tracker
          const SEEN_KEY = "codpet_seen_slugs";
          let seenSlugs = new Set(JSON.parse(localStorage.getItem(SEEN_KEY) || "[]"));
          
          window.updateNewBadges = function() {
            const tiles = document.querySelectorAll(".tile");
            if (tiles.length === 0) return;
            
            if (seenSlugs.size === 0) {
              // First run: mark all current pets as seen
              const allSlugs = Array.from(tiles).map(t => t.dataset.slug);
              seenSlugs = new Set(allSlugs);
              localStorage.setItem(SEEN_KEY, JSON.stringify(Array.from(seenSlugs)));
            } else {
              tiles.forEach(tile => {
                const slug = tile.dataset.slug;
                if (!seenSlugs.has(slug)) {
                  tile.classList.add("is-new-pet");
                }
              });
            }
          };

          // Hover listeners to clear NEW badge
          document.addEventListener("mouseenter", function(event) {
            const tile = event.target.closest(".tile");
            if (!tile) return;
            const slug = tile.dataset.slug;
            if (tile.classList.contains("is-new-pet")) {
              tile._seenTimeout = setTimeout(() => {
                tile.classList.remove("is-new-pet");
                seenSlugs.add(slug);
                localStorage.setItem(SEEN_KEY, JSON.stringify(Array.from(seenSlugs)));
              }, 1000);
            }
          }, true);

          document.addEventListener("mouseleave", function(event) {
            const tile = event.target.closest(".tile");
            if (!tile) return;
            if (tile._seenTimeout) {
              clearTimeout(tile._seenTimeout);
              delete tile._seenTimeout;
            }
          }, true);

          // Unified Click Router
          document.addEventListener("click", function(event) {
            const actionBtn = event.target.closest(".app-action-btn");
            const tile = event.target.closest(".tile");
            
            if (actionBtn) {
              event.preventDefault();
              event.stopPropagation();
              event.stopImmediatePropagation();
              
              const slug = actionBtn.dataset.slug;
              const action = actionBtn.dataset.action;
              
              window.webkit.messageHandlers.codpetNative.postMessage({
                type: action,
                slug: slug
              });
              return;
            }
            
            if (tile) {
              event.preventDefault();
              event.stopPropagation();
              event.stopImmediatePropagation();
              
              const slug = tile.dataset.slug;
              const isInstalled = tile.classList.contains("native-installed");
              
              window.webkit.messageHandlers.codpetNative.postMessage({
                type: isInstalled ? "apply" : "install",
                slug: slug
              });
            }
          }, true);

          window.codpetNativeSync = function(payload) {
            const installed = new Set((payload && payload.installed) || []);
            const active = payload && payload.active ? payload.active : "";
            
            // Check & draw NEW badges
            if (typeof window.updateNewBadges === "function") {
              window.updateNewBadges();
            }
            
            document.querySelectorAll(".tile").forEach((tile) => {
              const slug = tile.dataset.slug;
              const isInstalled = installed.has(slug);
              const isActive = slug === active;
              
              tile.classList.toggle("native-installed", isInstalled);
              tile.classList.toggle("native-active", isActive);
              
              // Append (using) to display name if active, restore base name if not
              const nameEl = tile.querySelector(".tile-name");
              if (nameEl) {
                if (!nameEl._baseName) {
                  nameEl._baseName = nameEl.textContent;
                }
                nameEl.textContent = isActive ? nameEl._baseName + " (using)" : nameEl._baseName;
              }

              // Active companion continuous play
              const wasActivePlay = !!tile._isActivePlay;
              tile._isActivePlay = isActive;
              if (isActive) {
                if (!wasActivePlay) {
                  startHover(tile);
                }
              } else {
                if (wasActivePlay) {
                  if (!tile._isHovered) {
                    stopHover(tile);
                  }
                }
              }
              
              let labelEl = tile.querySelector(".tile-label");
              if (labelEl) {
                let actionBtn = labelEl.querySelector(".app-action-btn");
                if (!actionBtn) {
                  actionBtn = document.createElement("button");
                  actionBtn.type = "button";
                  actionBtn.className = "app-action-btn";
                  labelEl.appendChild(actionBtn);
                }
                
                actionBtn.dataset.slug = slug;
                if (isInstalled) {
                  actionBtn.className = "app-action-btn delete-btn";
                  actionBtn.innerHTML = trashIcon;
                  actionBtn.dataset.action = "uninstall";
                  actionBtn.title = "Delete local pet";
                } else {
                  actionBtn.className = "app-action-btn install-btn";
                  actionBtn.innerHTML = downloadIcon;
                  actionBtn.dataset.action = "install";
                  actionBtn.title = "Install locally";
                }
              }
            });
          };
        })();
        """
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var store: CodpetHybridStore
        
        init(store: CodpetHybridStore) {
            self.store = store
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "codpetNative",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let slug = body["slug"] as? String else {
                return
            }
            
            switch type {
            case "install":
                store.installPet(slug: slug)
            case "apply":
                _ = store.applyPet(slug: slug)
            case "uninstall":
                store.uninstallPet(slug: slug)
            default:
                break
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncInstalledState(in: webView)
        }
        
        func syncInstalledState(in webView: WKWebView) {
            let script = "window.codpetNativeSync && window.codpetNativeSync(\(store.installedSlugsJSON()))"
            webView.evaluateJavaScript(script)
        }
    }
}
