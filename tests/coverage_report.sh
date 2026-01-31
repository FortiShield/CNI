#!/bin/bash

# Test Coverage Report Generator
# Generates comprehensive test coverage reports and quality metrics

set -euo pipefail

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Configuration
REPORT_DIR="${REPORT_DIR:-/tmp/test-results}"
COVERAGE_DIR="${COVERAGE_DIR:-${REPORT_DIR}/coverage}"
REPORT_DATE=$(date +%Y-%m-%d)
REPORT_TIME=$(date +%H:%M:%S)
HTML_REPORT="${COVERAGE_DIR}/coverage_report_${REPORT_DATE}.html"
JSON_REPORT="${COVERAGE_DIR}/coverage_report_${REPORT_DATE}.json"

# Ensure directories exist
mkdir -p "$COVERAGE_DIR"

# Colors for HTML report
HTML_COLORS=(
    "#28a745"  # Green for success
    "#dc3545"  # Red for failure
    "#ffc107"  # Yellow for warning
    "#17a2b8"  # Cyan for info
    "#6f42c1"  # Purple for special
)

# Function to generate HTML header
generate_html_header() {
    local title="$1"
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .nav-tabs {
            display: flex;
            background: #e9ecef;
            border-bottom: 2px solid #dee2e6;
        }
        .nav-tab {
            padding: 15px 25px;
            cursor: pointer;
            border: none;
            background: none;
            font-size: 14px;
            font-weight: 500;
            color: #495057;
            transition: all 0.3s ease;
        }
        .nav-tab:hover {
            background: #dee2e6;
        }
        .nav-tab.active {
            background: white;
            color: #495057;
            border-bottom: 2px solid #007bff;
        }
        .tab-content {
            display: none;
            padding: 30px;
        }
        .tab-content.active {
            display: block;
        }
        .metric-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #007bff;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #495057;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #6c757d;
            font-size: 0.9em;
        }
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e9ecef;
            border-radius: 4px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: #28a745;
            transition: width 0.3s ease;
        }
        .test-suite {
            margin-bottom: 25px;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            overflow: hidden;
        }
        .suite-header {
            background: #f8f9fa;
            padding: 15px 20px;
            font-weight: 600;
            border-bottom: 1px solid #dee2e6;
        }
        .suite-content {
            padding: 20px;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8em;
            font-weight: 500;
            text-transform: uppercase;
        }
        .status-passed {
            background: #d4edda;
            color: #155724;
        }
        .status-failed {
            background: #f8d7da;
            color: #721c24;
        }
        .status-warning {
            background: #fff3cd;
            color: #856404;
        }
        .chart-container {
            height: 300px;
            margin: 20px 0;
            position: relative;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            font-size: 0.9em;
            border-top: 1px solid #dee2e6;
        }
        @media (max-width: 768px) {
            .metric-grid {
                grid-template-columns: 1fr;
            }
            .nav-tabs {
                flex-direction: column;
            }
            .nav-tab {
                border-bottom: 1px solid #dee2e6;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>CNI Test Coverage Report</h1>
            <p>Generated on $REPORT_DATE at $REPORT_TIME</p>
        </div>
EOF
}

# Function to generate HTML footer
generate_html_footer() {
    cat << EOF
        <div class="footer">
            <p>CNI Container Build System - Automated Test Coverage Report</p>
            <p>This report is automatically generated as part of the CI/CD pipeline</p>
        </div>
    </div>
    <script>
        // Tab switching functionality
        document.querySelectorAll('.nav-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                // Remove active class from all tabs and contents
                document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
                document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
                
                // Add active class to clicked tab and corresponding content
                tab.classList.add('active');
                const tabId = tab.getAttribute('data-tab');
                document.getElementById(tabId).classList.add('active');
            });
        });
        
        // Set first tab as active by default
        document.querySelector('.nav-tab').click();
    </script>
</body>
</html>
EOF
}

# Function to parse test results
parse_test_results() {
    local results_dir="$1"
    local component="$2"
    
    local results_file="${results_dir}/${component}.results"
    
    if [[ ! -f "$results_file" ]]; then
        echo '{"total": 0, "passed": 0, "failed": 0, "skipped": 0, "status": "no_results"}'
        return
    fi
    
    local total=$(grep "Total Tests:" "$results_file" | awk '{print $3}' || echo "0")
    local passed=$(grep "Passed:" "$results_file" | awk '{print $2}' || echo "0")
    local failed=$(grep "Failed:" "$results_file" | awk '{print $2}' || echo "0")
    local skipped=$(grep "Skipped:" "$results_file" | awk '{print $2}' || echo "0")
    local status=$(grep "Result:" "$results_file" | awk '{print $2}' || echo "unknown")
    
    cat << EOF
{
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped,
    "status": "$status"
}
EOF
}

# Function to calculate overall metrics
calculate_overall_metrics() {
    local results_dir="$1"
    
    local total_tests=0
    local total_passed=0
    local total_failed=0
    local total_skipped=0
    local components_tested=0
    local components_passed=0
    
    # Process all result files
    for results_file in "$results_dir"/*.results; do
        if [[ -f "$results_file" ]]; then
            local component_name=$(basename "$results_file" .results)
            local component_data
            component_data=$(parse_test_results "$results_dir" "$component_name")
            
            local comp_total=$(echo "$component_data" | jq -r '.total // 0')
            local comp_passed=$(echo "$component_data" | jq -r '.passed // 0')
            local comp_failed=$(echo "$component_data" | jq -r '.failed // 0')
            local comp_skipped=$(echo "$component_data" | jq -r '.skipped // 0')
            local comp_status=$(echo "$component_data" | jq -r '.status // "unknown"')
            
            total_tests=$((total_tests + comp_total))
            total_passed=$((total_passed + comp_passed))
            total_failed=$((total_failed + comp_failed))
            total_skipped=$((total_skipped + comp_skipped))
            components_tested=$((components_tested + 1))
            
            if [[ "$comp_status" == "PASSED" ]]; then
                components_passed=$((components_passed + 1))
            fi
        fi
    done
    
    # Calculate success rate
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((total_passed * 100 / total_tests))
    fi
    
    # Calculate component success rate
    local component_success_rate=0
    if [[ $components_tested -gt 0 ]]; then
        component_success_rate=$((components_passed * 100 / components_tested))
    fi
    
    cat << EOF
{
    "total_tests": $total_tests,
    "total_passed": $total_passed,
    "total_failed": $total_failed,
    "total_skipped": $total_skipped,
    "components_tested": $components_tested,
    "components_passed": $components_passed,
    "success_rate": $success_rate,
    "component_success_rate": $component_success_rate
}
EOF
}

# Function to generate HTML metrics section
generate_html_metrics() {
    local metrics="$1"
    
    local total_tests=$(echo "$metrics" | jq -r '.total_tests')
    local total_passed=$(echo "$metrics" | jq -r '.total_passed')
    local total_failed=$(echo "$metrics" | jq -r '.total_failed')
    local components_tested=$(echo "$metrics" | jq -r '.components_tested')
    local components_passed=$(echo "$metrics" | jq -r '.components_passed')
    local success_rate=$(echo "$metrics" | jq -r '.success_rate')
    local component_success_rate=$(echo "$metrics" | jq -r '.component_success_rate')
    
    cat << EOF
        <div class="tab-content active" id="overview">
            <div class="metric-grid">
                <div class="metric-card">
                    <div class="metric-value">$total_tests</div>
                    <div class="metric-label">Total Tests</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" style="color: #28a745;">$total_passed</div>
                    <div class="metric-label">Tests Passed</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" style="color: #dc3545;">$total_failed</div>
                    <div class="metric-label">Tests Failed</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$components_tested</div>
                    <div class="metric-label">Components Tested</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$success_rate%</div>
                    <div class="metric-label">Test Success Rate</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${success_rate}%;"></div>
                    </div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$component_success_rate%</div>
                    <div class="metric-label">Component Success Rate</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${component_success_rate}%;"></div>
                    </div>
                </div>
            </div>
EOF
}

# Function to generate component breakdown
generate_component_breakdown() {
    local results_dir="$1"
    
    cat << EOF
            <h3>Component Test Results</h3>
EOF
    
    # Process each component
    for results_file in "$results_dir"/*.results; do
        if [[ -f "$results_file" ]]; then
            local component_name=$(basename "$results_file" .results)
            local component_data
            component_data=$(parse_test_results "$results_dir" "$component_name")
            
            local total=$(echo "$component_data" | jq -r '.total')
            local passed=$(echo "$component_data" | jq -r '.passed')
            local failed=$(echo "$component_data" | jq -r '.failed')
            local skipped=$(echo "$component_data" | jq -r '.skipped')
            local status=$(echo "$component_data" | jq -r '.status')
            
            local success_rate=0
            if [[ $total -gt 0 ]]; then
                success_rate=$((passed * 100 / total))
            fi
            
            local status_class="status-warning"
            if [[ "$status" == "PASSED" ]]; then
                status_class="status-passed"
            elif [[ "$status" == "FAILED" ]]; then
                status_class="status-failed"
            fi
            
            cat << EOF
            <div class="test-suite">
                <div class="suite-header">
                    $component_name
                    <span class="status-badge $status_class" style="float: right;">$status</span>
                </div>
                <div class="suite-content">
                    <div class="metric-grid" style="grid-template-columns: repeat(4, 1fr);">
                        <div class="metric-card">
                            <div class="metric-value">$total</div>
                            <div class="metric-label">Total Tests</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: #28a745;">$passed</div>
                            <div class="metric-label">Passed</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: #dc3545;">$failed</div>
                            <div class="metric-label">Failed</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">$success_rate%</div>
                            <div class="metric-label">Success Rate</div>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${success_rate}%;"></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
EOF
        fi
    done
}

# Function to generate JSON report
generate_json_report() {
    local results_dir="$1"
    local output_file="$2"
    
    local overall_metrics
    overall_metrics=$(calculate_overall_metrics "$results_dir")
    
    local components_data="{"
    local first=true
    
    for results_file in "$results_dir"/*.results; do
        if [[ -f "$results_file" ]]; then
            local component_name=$(basename "$results_file" .results)
            local component_data
            component_data=$(parse_test_results "$results_dir" "$component_name")
            
            if [[ "$first" == "true" ]]; then
                first=false
            else
                components_data+=","
            fi
            components_data+="\"$component_name\": $component_data"
        fi
    done
    components_data+="}"
    
    cat << EOF > "$output_file"
{
    "report_metadata": {
        "generated_date": "$REPORT_DATE",
        "generated_time": "$REPORT_TIME",
        "report_version": "1.0"
    },
    "overall_metrics": $overall_metrics,
    "components": $components_data
}
EOF
}

# Function to generate complete HTML report
generate_html_report() {
    local results_dir="$1"
    local output_file="$2"
    
    local overall_metrics
    overall_metrics=$(calculate_overall_metrics "$results_dir")
    
    # Start HTML document
    generate_html_header "CNI Test Coverage Report" > "$output_file"
    
    # Add navigation tabs
    cat << EOF >> "$output_file"
        <div class="nav-tabs">
            <button class="nav-tab" data-tab="overview">Overview</button>
            <button class="nav-tab" data-tab="components">Components</button>
            <button class="nav-tab" data-tab="trends">Trends</button>
            <button class="nav-tab" data-tab="quality">Quality Gates</button>
        </div>
EOF
    
    # Add overview tab
    generate_html_metrics "$overall_metrics" >> "$output_file"
    generate_component_breakdown "$results_dir" >> "$output_file"
    cat << EOF >> "$output_file"
        </div>
        
        <div class="tab-content" id="components">
            <h3>Component Coverage Details</h3>
            <p>Detailed breakdown of test coverage for each component.</p>
            <!-- Component details will be populated here -->
        </div>
        
        <div class="tab-content" id="trends">
            <h3>Test Trends</h3>
            <p>Historical test performance and coverage trends.</p>
            <!-- Trend charts will be populated here -->
        </div>
        
        <div class="tab-content" id="quality">
            <h3>Quality Gates</h3>
            <p>Quality metrics and gate status.</p>
            <!-- Quality gate information will be populated here -->
        </div>
EOF
    
    # Close HTML document
    generate_html_footer >> "$output_file"
}

# Main function
main() {
    local results_dir="${1:-$REPORT_DIR}"
    
    log_info "Generating test coverage report"
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for JSON processing but is not installed"
        exit 1
    fi
    
    # Generate JSON report
    log_info "Generating JSON coverage report"
    generate_json_report "$results_dir" "$JSON_REPORT"
    
    # Generate HTML report
    log_info "Generating HTML coverage report"
    generate_html_report "$results_dir" "$HTML_REPORT"
    
    log_success "Coverage reports generated:"
    log_success "  HTML: $HTML_REPORT"
    log_success "  JSON: $JSON_REPORT"
    
    # Display summary
    local overall_metrics
    overall_metrics=$(calculate_overall_metrics "$results_dir")
    
    local total_tests=$(echo "$overall_metrics" | jq -r '.total_tests')
    local total_passed=$(echo "$overall_metrics" | jq -r '.total_passed')
    local total_failed=$(echo "$overall_metrics" | jq -r '.total_failed')
    local success_rate=$(echo "$overall_metrics" | jq -r '.success_rate')
    
    echo
    echo "=== Coverage Summary ==="
    echo "Total Tests: $total_tests"
    echo "Passed: $total_passed"
    echo "Failed: $total_failed"
    echo "Success Rate: $success_rate%"
    echo "========================"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
