K_SEM_DEFINE(dhcp_ready, 0, 1);

static bool
check_dhcp(struct net_if *iface)
{
	// Scan IP addresses allocated for Unicast
	for (int i = 0; i < NET_IF_MAX_IPV4_ADDR; i++) {
		if (iface->config.ip.ipv4->unicast[i].addr_type != NET_ADDR_DHCP)
			continue;
		return true;
	}

	return false;
}

static void
dhcp_handler(struct net_mgmt_event_callback *cb,
		uint32_t ev,
		struct net_if *iface)
{
	if (ev != NET_EVENT_IPV4_ADDR_ADD)
		return;
	if (check_dhcp(iface))
		k_sem_give(&dhcp_ready);
}

static void
setup_dhcp(void)
{

	static struct net_mgmt_event_callback cb;
	net_mgmt_init_event_callback(&cb, dhcp_handler, NET_EVENT_IPV4_ADDR_ADD);
	net_mgmt_add_event_callback(&cb);

	struct net_if *iface = net_if_get_default();

	if (!check_dhcp(iface)) {
		net_dhcpv4_start(iface);
		k_sem_take(&dhcp_ready, K_FOREVER);
	}
}

