import XCTest
@testable import DevBar

final class DevBarTests: XCTestCase {

    // MARK: - Tests PortScanner - Column Parsing

    func testParseLsofOutputSingleServer() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.port, 3000)
        XCTAssertEqual(parsed.first?.pid, 1234)
        XCTAssertEqual(parsed.first?.processName, "node")
    }

    func testParseLsofOutputMultipleServers() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        ruby      5678  user   21u  IPv4 0x1234567890abcdef      0t0  TCP *:3001 (LISTEN)
        python    9012  user   22u  IPv4 0x1234567890abcdef      0t0  TCP 127.0.0.1:8000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].port, 3000)
        XCTAssertEqual(parsed[1].port, 3001)
        XCTAssertEqual(parsed[2].port, 8000)
    }

    func testParseLsofOutputEmpty() {
        let scanner = PortScanner()
        XCTAssertTrue(scanner.parseLsofOutput("").isEmpty)
    }

    func testParseLsofOutputHeaderOnly() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        """
        XCTAssertTrue(scanner.parseLsofOutput(output).isEmpty)
    }

    func testParseLsofOutputFiltersSystemPorts() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        launchd   1     root   10u  IPv4 0x1234567890abcdef      0t0  TCP *:80 (LISTEN)
        web       100   user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.port, 3000)
    }

    func testParseLsofOutputFiltersDynamicPorts() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        app       100   user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:60000 (LISTEN)
        web       200   user   21u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.port, 3000)
    }

    func testParseLsofOutputDeduplicatesPort() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        node      1234  user   21u  IPv6 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 1)
    }

    func testParseLsofOutputIgnoresNonListen() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x1234567890abcdef      0t0  TCP 127.0.0.1:3000->127.0.0.1:5000 (ESTABLISHED)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertTrue(parsed.isEmpty)
    }

    func testParseLsofOutputIPv6() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        postgres  80609 user   5u   IPv6 0x1234567890abcdef      0t0  TCP [::1]:5432 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.port, 5432)
        XCTAssertEqual(parsed.first?.processName, "postgres")
    }

    func testParseLsofOutputSortedByPort() {
        let scanner = PortScanner()
        let output = """
        COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        python    9012  user   22u  IPv4 0x1234567890abcdef      0t0  TCP 127.0.0.1:8000 (LISTEN)
        node      1234  user   20u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
        """

        let parsed = scanner.parseLsofOutput(output)

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].port, 3000)
        XCTAssertEqual(parsed[1].port, 8000)
    }

    // MARK: - Tests ServerType Detection

    func testDetectServerTypeNodeProcess() {
        let scanner = PortScanner()
        XCTAssertEqual(scanner.detectServerType(processName: "node", cwd: ""), .express)
        XCTAssertEqual(scanner.detectServerType(processName: "next-server", cwd: ""), .nextjs)
        XCTAssertEqual(scanner.detectServerType(processName: "vite", cwd: ""), .vite)
    }

    func testDetectServerTypeRubyProcess() {
        let scanner = PortScanner()
        XCTAssertEqual(scanner.detectServerType(processName: "rails", cwd: ""), .rails)
        XCTAssertEqual(scanner.detectServerType(processName: "ruby", cwd: ""), .rails)
        XCTAssertEqual(scanner.detectServerType(processName: "puma", cwd: ""), .rails)
    }

    func testDetectServerTypePythonProcess() {
        let scanner = PortScanner()
        XCTAssertEqual(scanner.detectServerType(processName: "python3", cwd: ""), .python)
        XCTAssertEqual(scanner.detectServerType(processName: "python", cwd: ""), .python)
        XCTAssertEqual(scanner.detectServerType(processName: "uvicorn", cwd: ""), .fastapi)
    }

    func testDetectServerTypeUnknown() {
        let scanner = PortScanner()
        XCTAssertEqual(scanner.detectServerType(processName: "unknown", cwd: ""), .unknown)
    }

    // MARK: - Tests TunnelManager

    func testExtractCloudflareURL() {
        let output1 = "Your quick Tunnel has been created! Visit it at https://random-name.trycloudflare.com"
        XCTAssertNotNil(TunnelManager.extractCloudflareURLStatic(from: output1))
        XCTAssertEqual(
            TunnelManager.extractCloudflareURLStatic(from: output1),
            "https://random-name.trycloudflare.com"
        )

        let output2 = "No URL here"
        XCTAssertNil(TunnelManager.extractCloudflareURLStatic(from: output2))

        let output3 = "URL: https://abc-123-def.trycloudflare.com/path"
        XCTAssertEqual(
            TunnelManager.extractCloudflareURLStatic(from: output3),
            "https://abc-123-def.trycloudflare.com"
        )
    }

    func testExtractCloudflareURLMultiple() {
        let output = """
        URL 1: https://first-url.trycloudflare.com
        URL 2: https://second-url.trycloudflare.com
        """
        let url = TunnelManager.extractCloudflareURLStatic(from: output)
        XCTAssertNotNil(url)
        XCTAssertEqual(url, "https://first-url.trycloudflare.com")
    }

    // MARK: - Tests CloudflaredBundler

    func testCurrentArchitecture() {
        let bundler = CloudflaredBundler.shared
        let arch = bundler.currentArchitecture()

        #if arch(arm64)
        XCTAssertEqual(arch, "arm64")
        #else
        XCTAssertEqual(arch, "amd64")
        #endif
    }

    // MARK: - Tests ContainerScanner

    func testParseDockerPsOutput() {
        let scanner = ContainerScanner()
        let output = """
        {"ID":"abc123","Names":"my-container","Image":"nginx:latest","Status":"Up 2 hours","Ports":"0.0.0.0:80->80/tcp"}
        {"ID":"def456","Names":"redis","Image":"redis:7","Status":"Up 1 day","Ports":"6379/tcp"}
        """
        let containers = scanner.parseDockerPsOutput(output)
        XCTAssertEqual(containers.count, 2)
        XCTAssertEqual(containers[0].name, "my-container")
        XCTAssertEqual(containers[0].isRunning, true)
    }

    func testParseDockerPsOutputEmpty() {
        let scanner = ContainerScanner()
        XCTAssertTrue(scanner.parseDockerPsOutput("").isEmpty)
    }

    func testParseContainerStatus() {
        let scanner = ContainerScanner()
        let output = """
        {"ID":"1","Names":"c1","Image":"img","Status":"Up 5 minutes","Ports":""}
        {"ID":"2","Names":"c2","Image":"img","Status":"Exited (0) 2 hours ago","Ports":""}
        """
        let containers = scanner.parseDockerPsOutput(output)
        XCTAssertEqual(containers[0].status, .running)
        XCTAssertEqual(containers[1].status, .exited)
    }

    // MARK: - Tests Config

    func testDefaultConfig() {
        let config = DevBarConfig.shared
        XCTAssertGreaterThan(config.refreshInterval, 0)
        XCTAssertFalse(config.autoStartTunnels)
        XCTAssertTrue(config.showTailscaleBadge)
    }
}
