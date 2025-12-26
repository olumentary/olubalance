import { Controller } from '@hotwired/stimulus';
import { Chart, registerables } from 'chart.js';

// Register all Chart.js components
Chart.register(...registerables);

export default class extends Controller {
  static values = {
    type: String,
    labels: Array,
    currentData: Array,
    previousData: Array,
    currentLabel: String,
    previousLabel: String,
  };

  connect() {
    this.initChart();
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
    }
  }

  initChart() {
    const ctx = this.element.getContext('2d');

    if (this.typeValue === 'bar') {
      this.createBarChart(ctx);
    } else if (this.typeValue === 'doughnut') {
      this.createDoughnutChart(ctx);
    }
  }

  createBarChart(ctx) {
    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            label: this.currentLabelValue,
            data: this.currentDataValue,
            backgroundColor: 'rgba(54, 162, 235, 0.8)',
            borderColor: 'rgba(54, 162, 235, 1)',
            borderWidth: 1,
          },
          {
            label: this.previousLabelValue,
            data: this.previousDataValue,
            backgroundColor: 'rgba(201, 203, 207, 0.8)',
            borderColor: 'rgba(201, 203, 207, 1)',
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const value = context.raw || 0;
                return `${context.dataset.label}: $${value.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                })}`;
              },
            },
          },
        },
        scales: {
          x: {
            ticks: {
              maxRotation: 45,
              minRotation: 45,
            },
          },
          y: {
            beginAtZero: true,
            ticks: {
              callback: (value) => '$' + value.toLocaleString(),
            },
          },
        },
      },
    });
  }

  createDoughnutChart(ctx) {
    // Generate colors for each category
    const colors = this.generateColors(this.labelsValue.length);

    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            data: this.currentDataValue,
            backgroundColor: colors,
            borderColor: colors.map((c) => c.replace('0.8', '1')),
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'right',
            labels: {
              boxWidth: 12,
              padding: 10,
            },
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const value = context.raw || 0;
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                return `${context.label}: $${value.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                })} (${percentage}%)`;
              },
            },
          },
        },
      },
    });
  }

  generateColors(count) {
    const baseColors = [
      'rgba(54, 162, 235, 0.8)', // Blue
      'rgba(255, 99, 132, 0.8)', // Red
      'rgba(75, 192, 192, 0.8)', // Teal
      'rgba(255, 206, 86, 0.8)', // Yellow
      'rgba(153, 102, 255, 0.8)', // Purple
      'rgba(255, 159, 64, 0.8)', // Orange
      'rgba(46, 204, 113, 0.8)', // Green
      'rgba(52, 73, 94, 0.8)', // Dark grey
      'rgba(231, 76, 60, 0.8)', // Dark red
      'rgba(155, 89, 182, 0.8)', // Violet
      'rgba(26, 188, 156, 0.8)', // Turquoise
      'rgba(241, 196, 15, 0.8)', // Sunflower
    ];

    const colors = [];
    for (let i = 0; i < count; i++) {
      colors.push(baseColors[i % baseColors.length]);
    }
    return colors;
  }
}

