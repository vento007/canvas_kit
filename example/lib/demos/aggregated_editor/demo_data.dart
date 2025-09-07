import 'package:flutter/material.dart';
import 'aggregated_models.dart';

/// Corporate VPN Endpoint Management Demo Data
/// 
/// This represents a realistic corporate network scenario with:
/// - 10 users across different departments
/// - 4 device groups (mobile, laptop, desktop, IoT)
/// - 6 security policies for different access levels
/// - 40+ corporate assets (servers, databases, applications)
/// - Comprehensive connection mappings

class DemoData {
  static const double baseX = 120.0;
  static const double nodeSpacing = 400.0;
  
  // Users Node - 10 corporate users from different departments
  static final AggNode usersNode = AggNode(
    id: 'users',
    title: 'Applications',
    position: const Offset(baseX, 120),
    items: const [
      AggItem(
        id: 'u:alice.smith',
        label: 'App Alpha',
        children: [
          AggItem(id: 'u:alice.smith:iphone', label: 'iOS build'),
          AggItem(id: 'u:alice.smith:macbook', label: 'Desktop build (macOS)'),
          AggItem(id: 'u:alice.smith:ipad', label: 'Tablet build'),
        ],
      ),
      AggItem(
        id: 'u:bob.johnson',
        label: 'App Beta',
        children: [
          AggItem(id: 'u:bob.johnson:pixel', label: 'Android build'),
          AggItem(id: 'u:bob.johnson:thinkpad', label: 'Laptop build'),
          AggItem(id: 'u:bob.johnson:desktop', label: 'Desktop build'),
        ],
      ),
      AggItem(
        id: 'u:carol.davis',
        label: 'App Gamma',
        children: [
          AggItem(id: 'u:carol.davis:iphone', label: 'iOS build'),
          AggItem(id: 'u:carol.davis:surface', label: 'Laptop build'),
        ],
      ),
      AggItem(
        id: 'u:david.wilson',
        label: 'App Delta',
        children: [
          AggItem(id: 'u:david.wilson:galaxy', label: 'Android build'),
          AggItem(id: 'u:david.wilson:macbook', label: 'Desktop build (macOS)'),
        ],
      ),
      AggItem(
        id: 'u:eva.martinez',
        label: 'App Epsilon',
        children: [
          AggItem(id: 'u:eva.martinez:oneplus', label: 'Android build'),
          AggItem(id: 'u:eva.martinez:linux', label: 'Desktop build (Linux)'),
          AggItem(id: 'u:eva.martinez:server', label: 'Server build'),
        ],
      ),
      AggItem(
        id: 'u:frank.brown',
        label: 'App Zeta',
        children: [
          AggItem(id: 'u:frank.brown:iphone', label: 'iOS build'),
          AggItem(id: 'u:frank.brown:macbook', label: 'Desktop build (macOS)'),
        ],
      ),
      AggItem(
        id: 'u:grace.lee',
        label: 'App Eta',
        children: [
          AggItem(id: 'u:grace.lee:samsung', label: 'Android build'),
          AggItem(id: 'u:grace.lee:surface', label: 'Desktop build (Windows)'),
        ],
      ),
      AggItem(
        id: 'u:henry.clark',
        label: 'App Theta',
        children: [
          AggItem(id: 'u:henry.clark:iphone', label: 'iOS build'),
          AggItem(id: 'u:henry.clark:desktop', label: 'Desktop build'),
        ],
      ),
      AggItem(
        id: 'u:iris.taylor',
        label: 'App Iota',
        children: [
          AggItem(id: 'u:iris.taylor:pixel', label: 'Android build'),
          AggItem(id: 'u:iris.taylor:laptop', label: 'Laptop build'),
        ],
      ),
      AggItem(
        id: 'u:jack.white',
        label: 'App Kappa',
        children: [
          AggItem(id: 'u:jack.white:iphone', label: 'iOS build'),
          AggItem(id: 'u:jack.white:desktop', label: 'Desktop build'),
        ],
      ),
    ],
    height: 450, // Increased height for more users
    inPortsSide: PortSide.none,
    outPortsSide: PortSide.right,
  );

  // Device Groups Node - 4 categories of managed devices
  static final AggNode deviceGroupsNode = AggNode(
    id: 'device_groups',
    title: 'Subsystems',
    position: Offset(baseX + nodeSpacing, 100),
    items: const [
      AggItem(id: 'dg:mobile', label: 'Mobile'),
      AggItem(id: 'dg:laptops', label: 'Laptops'),
      AggItem(id: 'dg:workstations', label: 'Desktops'),
      AggItem(id: 'dg:iot', label: 'Edge/IoT'),
    ],
    height: 200,
    inPortsSide: PortSide.left,
    outPortsSide: PortSide.right,
  );

  // Security Policies Node - 6 comprehensive security policies
  static final AggNode securityPoliciesNode = AggNode(
    id: 'security_policies',
    title: 'Capabilities',
    position: Offset(baseX + nodeSpacing * 2, 80),
    items: const [
      AggItem(id: 'sp:executive', label: 'exec'),
      AggItem(id: 'sp:admin', label: 'admin'),
      AggItem(id: 'sp:developer', label: 'developer'),
      AggItem(id: 'sp:employee', label: 'standard'),
      AggItem(id: 'sp:contractor', label: 'contractor'),
      AggItem(id: 'sp:guest', label: 'guest'),
    ],
    height: 250,
    inPortsSide: PortSide.left,
    outPortsSide: PortSide.right,
  );

  // Corporate Assets Node - 40+ realistic corporate resources
  static final AggNode corporateAssetsNode = AggNode(
    id: 'corporate_assets',
    title: 'Services',
    position: Offset(baseX + nodeSpacing * 3, 60),
    items: const [
      // Web & Frontend Stuff
      AggItem(
        id: 'assets:web',
        label: 'Web Servers',
        children: [
          AggItem(id: 'assets:web:prod1', label: 'web-prod-01'),
          AggItem(id: 'assets:web:prod2', label: 'web-prod-02'),
          AggItem(id: 'assets:web:staging', label: 'web-staging'),
          AggItem(id: 'assets:web:api', label: 'api-gateway'),
          AggItem(id: 'assets:web:cdn', label: 'cloudflare-cdn'),
        ],
      ),
      // Database Cluster
      AggItem(
        id: 'assets:databases',
        label: 'Databases',
        children: [
          AggItem(id: 'assets:databases:main', label: 'db-primary'),
          AggItem(id: 'assets:databases:slave', label: 'db-replica-01'),
          AggItem(id: 'assets:databases:analytics', label: 'postgres-analytics'),
          AggItem(id: 'assets:databases:redis', label: 'redis-cache'),
          AggItem(id: 'assets:databases:backup', label: 'backup-nas'),
        ],
      ),
      // Dev & CI/CD
      AggItem(
        id: 'assets:dev',
        label: 'Dev Stuff',
        children: [
          AggItem(id: 'assets:dev:git', label: 'gitlab-server'),
          AggItem(id: 'assets:dev:jenkins', label: 'jenkins-box'),
          AggItem(id: 'assets:dev:docker', label: 'docker-registry'),
          AggItem(id: 'assets:dev:staging', label: 'staging-env'),
          AggItem(id: 'assets:dev:testing', label: 'test-runner'),
        ],
      ),
      // Office Infrastructure
      AggItem(
        id: 'assets:office',
        label: 'Office Servers',
        children: [
          AggItem(id: 'assets:office:email', label: 'exchange-mail'),
          AggItem(id: 'assets:office:file', label: 'fileserver-01'),
          AggItem(id: 'assets:office:crm', label: 'salesforce-vm'),
          AggItem(id: 'assets:office:helpdesk', label: 'jira-server'),
          AggItem(id: 'assets:office:wiki', label: 'confluence'),
        ],
      ),
      // Finance & Accounting
      AggItem(
        id: 'assets:finance',
        label: 'Finance Systems',
        children: [
          AggItem(id: 'assets:finance:erp', label: 'sap-server'),
          AggItem(id: 'assets:finance:payroll', label: 'payroll-db'),
          AggItem(id: 'assets:finance:quickbooks', label: 'accounting-vm'),
          AggItem(id: 'assets:finance:reports', label: 'bi-dashboard'),
        ],
      ),
      // Security & Monitoring
      AggItem(
        id: 'assets:security',
        label: 'Security',
        children: [
          AggItem(id: 'assets:security:firewall', label: 'pfsense-fw'),
          AggItem(id: 'assets:security:vpn', label: 'openvpn-gw'),
          AggItem(id: 'assets:security:ids', label: 'snort-ids'),
          AggItem(id: 'assets:security:siem', label: 'splunk-server'),
          AggItem(id: 'assets:security:ca', label: 'cert-authority'),
        ],
      ),
      // Infrastructure & Ops
      AggItem(
        id: 'assets:infra',
        label: 'Infrastructure',
        children: [
          AggItem(id: 'assets:infra:monitor', label: 'prometheus'),
          AggItem(id: 'assets:infra:logs', label: 'elasticsearch'),
          AggItem(id: 'assets:infra:grafana', label: 'grafana-dash'),
          AggItem(id: 'assets:infra:backup', label: 'veeam-backup'),
          AggItem(id: 'assets:infra:dns', label: 'bind-dns'),
        ],
      ),
      // Cloud & External
      AggItem(
        id: 'assets:cloud',
        label: 'Cloud Stuff',
        children: [
          AggItem(id: 'assets:cloud:aws', label: 'aws-prod'),
          AggItem(id: 'assets:cloud:s3', label: 's3-buckets'),
          AggItem(id: 'assets:cloud:office365', label: 'office365'),
          AggItem(id: 'assets:cloud:gsuite', label: 'google-workspace'),
        ],
      ),
      // Server Room Hardware
      AggItem(
        id: 'assets:hardware',
        label: 'Server Room',
        children: [
          AggItem(id: 'assets:hardware:rack1', label: 'serverroom-rack1'),
          AggItem(id: 'assets:hardware:rack2', label: 'serverroom-rack2'),
          AggItem(id: 'assets:hardware:ups', label: 'ups-battery'),
          AggItem(id: 'assets:hardware:switch', label: 'cisco-switch'),
          AggItem(id: 'assets:hardware:router', label: 'edge-router'),
        ],
      ),
    ],
    height: 600, // Much larger to accommodate all assets
    inPortsSide: PortSide.left,
    outPortsSide: PortSide.none,
  );

  // All nodes for the demo
  static List<AggNode> get allNodes => [
    usersNode,
    deviceGroupsNode,
    securityPoliciesNode,
    corporateAssetsNode,
  ];

  // Comprehensive connection mappings for realistic corporate access patterns
  static List<AggConnection> get demoConnections => [
    // Executive Access (Alice - CEO)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:alice.smith:macbook', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:executive', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:executive', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:finance:erp', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:executive', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:finance:quickbooks', kind: PortKind.inPort),
    ),

    // CTO Access (Bob - Technical Leadership)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:bob.johnson:thinkpad', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:bob.johnson:desktop', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:dev:git', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:web:api', kind: PortKind.inPort),
    ),

    // CISO Access (Carol - Security)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:carol.davis:surface', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:security:siem', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:security:firewall', kind: PortKind.inPort),
    ),

    // CFO Access (David - Finance)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:david.wilson:macbook', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:executive', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:executive', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:finance:payroll', kind: PortKind.inPort),
    ),

    // DevOps Access (Eva - Infrastructure)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:eva.martinez:linux', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:eva.martinez:server', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:infra:monitor', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:dev:jenkins', kind: PortKind.inPort),
    ),

    // Sales Access (Frank)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:frank.brown:macbook', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:office:crm', kind: PortKind.inPort),
    ),

    // Marketing Access (Grace)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:grace.lee:surface', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:office:wiki', kind: PortKind.inPort),
    ),

    // Support Access (Henry)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:henry.clark:desktop', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:office:helpdesk', kind: PortKind.inPort),
    ),

    // HR Access (Iris)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:iris.taylor:laptop', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:laptops', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:finance:payroll', kind: PortKind.inPort),
    ),

    // Finance Access (Jack)
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:jack.white:desktop', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:workstations', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:finance:quickbooks', kind: PortKind.inPort),
    ),

    // Mobile Device Connections
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:alice.smith:iphone', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:mobile', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:bob.johnson:pixel', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:mobile', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'users', itemId: 'u:david.wilson:galaxy', kind: PortKind.out),
      to: AggPort(nodeId: 'device_groups', itemId: 'dg:mobile', kind: PortKind.inPort),
    ),

    // Mobile to Guest Network
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:mobile', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:guest', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'device_groups', itemId: 'dg:mobile', kind: PortKind.out),
      to: AggPort(nodeId: 'security_policies', itemId: 'sp:guest', kind: PortKind.inPort),
    ),

    // Guest Network to Limited Assets
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:guest', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:office:email', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:guest', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:security:vpn', kind: PortKind.inPort),
    ),

    // Developer-specific connections
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:developer', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:dev:staging', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:developer', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:dev:testing', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:developer', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:databases:slave', kind: PortKind.inPort),
    ),

    // Additional infrastructure connections
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:databases:main', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:web:prod1', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:admin', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:cloud:aws', kind: PortKind.inPort),
    ),

    // Common employee access
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:office:file', kind: PortKind.inPort),
    ),
    AggConnection(
      from: AggPort(nodeId: 'security_policies', itemId: 'sp:employee', kind: PortKind.out),
      to: AggPort(nodeId: 'corporate_assets', itemId: 'assets:cloud:office365', kind: PortKind.inPort),
    ),
  ];
}