Do's:

- Don't build the app unless I tell you to.
- Use xcode build to build for iOS 18 (iPhone 16 Pro). "xcodebuild -scheme Palytt -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' clean build"

- Update our backend at @palytt-backend folder when building features that required API integration.
- Update typings and enahnce type safety.
- Use tRPC connection for frontend and backend.
- Do not modify the @Package.swift file unless specifically asked to.
- If a new file is created, make sure to add it to @project.pbxproj.
- After building the app successfully, run it on our iPhone 16 Pro device.The simular is already running.
- For each view, create mock data for Preview Mode so we can Preview the View in Xcode.

Backend runs on:

🚀 Server ready at: <http://localhost:4000>
⚡ tRPC endpoint: <http://localhost:4000/trpc>
🌐 tRPC panel: <http://localhost:4000/trpc/panel>
💓 Health check: <http://localhost:4000/health>

[06:41:51 UTC] INFO: Server listening at <http://127.0.0.1:4000>
[06:41:51 UTC] INFO: Server listening at <http://192.168.1.75:4000>
[06:41:51 UTC] INFO: Server listening at <http://192.168.64.1:4000>
