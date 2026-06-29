import Foundation

enum RDPFile {
    static func contents(port: Int) -> String {
        """
        full address:s:127.0.0.1:\(port)
        gatewayprofileusagemethod:i:1
        gatewayusagemethod:i:0
        prompt for credentials:i:1
        authentication level:i:2
        enablecredsspsupport:i:1
        autoreconnection enabled:i:1
        screen mode id:i:2
        redirectclipboard:i:1
        """
    }
}
