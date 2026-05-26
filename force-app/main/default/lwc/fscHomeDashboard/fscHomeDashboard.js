import { LightningElement } from 'lwc';

export default class FscHomeDashboard extends LightningElement {
  cards = [
    {
      title: 'Leads',
      icon: 'standard:lead',
      count: 24,
      status: 'Active this week',
      link: '/lightning/o/Lead/list',
      color: '#0070D2'
    },
    {
      title: 'Accounts',
      icon: 'standard:account',
      count: 156,
      status: 'Total households',
      link: '/lightning/o/Account/list',
      color: '#06A3DF'
    },
    {
      title: 'Opportunities',
      icon: 'standard:opportunity',
      count: 38,
      status: 'In progress',
      link: '/lightning/o/Opportunity/list',
      color: '#1B96FF'
    },
    {
      title: 'Campaigns',
      icon: 'standard:campaign',
      count: 12,
      status: 'Active campaigns',
      link: '/lightning/o/Campaign/list',
      color: '#00A1DE'
    }
  ];

  dashboardMetrics = [
    { label: 'Total Leads', value: 247, change: '+12%', color: '#0070D2' },
    { label: 'Pursues This Week', value: 24, change: '+5', color: '#06A3DF' },
    { label: 'Conversion Rate', value: '18.2%', change: '+2.1%', color: '#1B96FF' },
    { label: 'Avg Response Time', value: '2.3h', change: '-0.5h', color: '#00A1DE' }
  ];

  recentActivity = [
    { name: 'Jennifer Park', action: 'Lead routed to Sarah Chen', time: '2 hours ago', icon: 'standard:lead', link: '/lightning/r/Lead/00QdM00000deeNGUAY/view' },
    { name: 'Marcus Reed', action: 'Added to nurture campaign', time: '4 hours ago', icon: 'standard:campaign', link: '/lightning/o/Campaign/list' },
    { name: 'Park Household', action: 'Account created', time: '6 hours ago', icon: 'standard:account', link: '/lightning/o/Account/list' }
  ];

  handleCardClick(event) {
    const link = event.currentTarget.dataset.link;
    window.location.href = link;
  }

  handleActivityClick(event) {
    const link = event.currentTarget.dataset.link;
    if (link) {
      window.location.href = link;
    }
  }

  handleActivityClick(event) {
    const link = event.currentTarget.dataset.link;
    if (link) {
      window.location.href = link;
    }
  }
}
