# BCP Xpress Demo
# Pre-requisites before recording:
#   1. ArgoCD is installed and running (./argocd/scripts/setup.sh already done)
#   2. Any previous hello-go app torn down: ./argocd/scripts/teardown.sh hello-go
#
# Record with: vhs demo.tape

Output demo.gif

Set FontSize 16
Set Width 1400
Set Height 800
Set Theme "Catppuccin Frappe"
Set Shell "zsh"
Set TypingSpeed 80ms
Set Padding 20
Set WindowBar Colorful
Set BorderRadius 8

Hide
Type "cd /Users/saradiaz/Documents/bcp-xpress/argocd"
Enter
Sleep 1s
Show

# ── 1. Show the developer descriptor ──
Type "# The only file a developer writes:"
Enter
Sleep 1500ms
Type "cat examples/app-build.yaml"
Enter
Sleep 4s

# ── 2. Register the app ──
Type "# Register the app with ArgoCD"
Enter
Sleep 1500ms
Type "./scripts/deploy.sh examples/app-build.yaml"
Enter
Sleep 6s

# ── 3. Push source → triggers GHA build ──
Type "# Push source — GitHub Actions builds the image"
Enter
Sleep 1500ms
Type "git add ../apps/hello-go && git commit -m 'app: hello-go' && git push"
Enter
Sleep 5s

# ── 4. Watch ArgoCD sync via kubectl ──
Type "# ArgoCD watches the repo and syncs automatically..."
Enter
Sleep 1500ms
Type "kubectl get application hello-go -n argocd -w"
Enter
Sleep 180s
Ctrl+C
Sleep 500ms

# ── 5. Show all resources ArgoCD deployed ──
Type "kubectl get application hello-go -n argocd -o wide"
Enter
Sleep 3s

Type "kubectl get deploy,svc,pods -l app=hello-go"
Enter
Sleep 3s

# ── 6. Test the app ──
Type "# Hit the app"
Enter
Sleep 1500ms
Type "kubectl port-forward svc/hello-go 8080:80 &"
Enter
Sleep 2s
Type "curl -s http://localhost:8080/ | jq ."
Enter
Sleep 2s
Type "curl -s http://localhost:8080/health | jq ."
Enter
Sleep 2s

Type "# From app.yaml to running service. No K8s knowledge needed. 🚀"
Enter
Sleep 4s
