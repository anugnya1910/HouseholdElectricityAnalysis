# ------------------------------------------------------------------------------
# Household Electricity Demand Dashboard (Shiny)
# Syllabus: Unit IV (Deploying models; documentation with R Markdown).
# Run from the project root with:  shiny::runApp("dashboard")
# ------------------------------------------------------------------------------
library(shiny)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(scales)
library(DT)

root <- if (file.exists("../data/processed/electricity_clean.csv")) ".." else "."
data_path <- file.path(root, "data/processed/electricity_clean.csv")
if (!file.exists(data_path)) stop("Run R/01_data_preparation.R first to create the processed dataset.")

df <- read_csv(data_path, show_col_types = FALSE) |>
  mutate(City = factor(City), MonthName = factor(MonthName, levels = month.abb),
         Season = factor(Season, levels = c("Winter", "Summer", "Monsoon", "Post-monsoon")))
peak_thr <- as.numeric(quantile(df$MonthlyHours, 0.75))

NAVY <- "#1F3A5F"; BLUE <- "#4F7CAC"; RED <- "#C8553D"; GREY <- "#8D99AE"
theme_dash <- function() {
  theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold", colour = NAVY), panel.grid.minor = element_blank(),
          legend.position = "bottom")
}

# Deployed models: fitted once at start-up on the full processed dataset.
fml_rhs <- "Fan + Refrigerator + AirConditioner + Television + Monitor + DaysInMonth + City"
m_lm  <- lm(as.formula(paste("MonthlyHours ~", fml_rhs)), data = df)
m_glm <- glm(as.formula(paste("PeakDemand ~", fml_rhs)), data = df, family = binomial)
days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
tariff_by_city <- df |> group_by(City) |> summarise(Tariff = mean(TariffRate), .groups = "drop")

css <- sprintf("
  body { background:#F5F7FA; font-family: 'Helvetica Neue', Arial, sans-serif; }
  .app-title { background:%s; color:white; padding:18px 28px; margin:-15px -15px 20px -15px; }
  .app-title h2 { margin:0; font-weight:600; font-size:22px; }
  .app-title p { margin:4px 0 0 0; color:#C9D3E0; font-size:13px; }
  .kpi { background:white; border-left:4px solid %s; padding:14px 18px; border-radius:3px;
         box-shadow:0 1px 2px rgba(0,0,0,.08); margin-bottom:15px; }
  .kpi .v { font-size:26px; font-weight:600; color:%s; }
  .kpi .l { font-size:12px; color:#6B7280; text-transform:uppercase; letter-spacing:.04em; }
  .panel-box { background:white; padding:14px; border-radius:3px; box-shadow:0 1px 2px rgba(0,0,0,.08); margin-bottom:15px; }
  .nav-tabs > li > a { color:%s; }
", NAVY, BLUE, NAVY, NAVY)

kpi <- function(value, label) div(class = "kpi", div(class = "v", value), div(class = "l", label))

ui <- fluidPage(
  tags$head(tags$style(HTML(css))),
  div(class = "app-title",
      h2("Household Electricity Consumption and Peak Demand Dashboard"),
      p("Introduction to Data Science case study  |  Artificial Intelligence and Data Science")),
  sidebarLayout(
    sidebarPanel(width = 3,
      h4("Filters"),
      selectizeInput("city", "City", choices = levels(df$City), selected = levels(df$City), multiple = TRUE),
      checkboxGroupInput("season", "Season", choices = levels(df$Season), selected = levels(df$Season)),
      sliderInput("ac", "Air conditioners", min = 0, max = 3, value = c(0, 3), step = 1),
      hr(),
      helpText(sprintf("Peak demand is defined as monthly consumption of at least %d hours (75th percentile).", round(peak_thr)))
    ),
    mainPanel(width = 9,
      fluidRow(
        column(3, uiOutput("k_n")), column(3, uiOutput("k_hours")),
        column(3, uiOutput("k_bill")), column(3, uiOutput("k_peak"))
      ),
      tabsetPanel(
        tabPanel("Consumption Patterns",
          br(),
          fluidRow(column(6, div(class = "panel-box", plotOutput("p_month", height = 300))),
                   column(6, div(class = "panel-box", plotOutput("p_dist", height = 300)))),
          fluidRow(column(6, div(class = "panel-box", plotOutput("p_city", height = 340))),
                   column(6, div(class = "panel-box", plotOutput("p_app", height = 340))))
        ),
        tabPanel("Peak Demand",
          br(),
          fluidRow(column(7, div(class = "panel-box", plotOutput("p_heat", height = 420))),
                   column(5, div(class = "panel-box", plotOutput("p_peakapp", height = 420))))
        ),
        tabPanel("Prediction Tool",
          br(),
          fluidRow(
            column(4, div(class = "panel-box",
              h4("Household profile"),
              selectInput("p_city", "City", levels(df$City)),
              selectInput("p_month", "Month", month.abb),
              sliderInput("p_fan", "Fan usage level", 5, 23, 14),
              sliderInput("p_ref", "Refrigerator usage level", 17, 23, 22),
              sliderInput("p_ac", "Air conditioners", 0, 3, 1, step = 1),
              sliderInput("p_tv", "Television usage level", 3, 22, 12),
              sliderInput("p_mon", "Monitor usage level", 1, 12, 1))),
            column(8,
              fluidRow(column(4, uiOutput("o_hours")), column(4, uiOutput("o_prob")), column(4, uiOutput("o_bill"))),
              div(class = "panel-box", plotOutput("p_contrib", height = 340)),
              helpText("Predictions come from a linear regression (consumption) and a logistic regression (peak probability) ",
                       "fitted on the full dataset. Bill estimate = predicted hours multiplied by the mean tariff of the selected city.")))
        ),
        tabPanel("Data", br(), DTOutput("tbl"))
      )
    )
  )
)

server <- function(input, output, session) {
  fd <- reactive({
    req(input$city, input$season)
    df |> filter(City %in% input$city, Season %in% input$season,
                 AirConditioner >= input$ac[1], AirConditioner <= input$ac[2])
  })
  guard <- function(d) validate(need(nrow(d) > 0, "No records match the selected filters."))

  output$k_n     <- renderUI(kpi(comma(nrow(fd())), "Household-months"))
  output$k_hours <- renderUI({ guard(fd()); kpi(round(mean(fd()$MonthlyHours)), "Mean monthly hours") })
  output$k_bill  <- renderUI({ guard(fd()); kpi(paste0("INR ", comma(round(mean(fd()$ElectricityBill)))), "Mean monthly bill") })
  output$k_peak  <- renderUI({ guard(fd()); kpi(percent(mean(fd()$PeakDemand), accuracy = 0.1), "Peak-demand share") })

  output$p_month <- renderPlot({
    guard(fd())
    fd() |> group_by(MonthName) |> summarise(Hours = mean(MonthlyHours), .groups = "drop") |>
      ggplot(aes(MonthName, Hours)) + geom_col(fill = NAVY, width = 0.7) +
      labs(title = "Mean Consumption by Month", x = NULL, y = "Monthly hours") + theme_dash()
  })
  output$p_dist <- renderPlot({
    guard(fd())
    ggplot(fd(), aes(MonthlyHours)) + geom_histogram(bins = 40, fill = BLUE, colour = "white") +
      geom_vline(xintercept = peak_thr, colour = RED, linetype = "dashed") +
      labs(title = "Consumption Distribution", x = "Monthly hours", y = "Count") + theme_dash()
  })
  output$p_city <- renderPlot({
    guard(fd())
    fd() |> group_by(City) |> summarise(Bill = mean(ElectricityBill), .groups = "drop") |>
      ggplot(aes(reorder(City, Bill), Bill)) + geom_col(fill = NAVY, width = 0.7) + coord_flip() +
      labs(title = "Mean Bill by City (INR)", x = NULL, y = NULL) + theme_dash()
  })
  output$p_app <- renderPlot({
    guard(fd())
    fd() |> mutate(AC = factor(AirConditioner)) |>
      ggplot(aes(AC, MonthlyHours)) + geom_boxplot(fill = "#E9EDF2", colour = NAVY, outlier.alpha = .2) +
      labs(title = "Consumption by Air Conditioner Count", x = "Air conditioners", y = "Monthly hours") + theme_dash()
  })
  output$p_heat <- renderPlot({
    guard(fd())
    fd() |> group_by(City, MonthName) |> summarise(Peak = mean(PeakDemand), .groups = "drop") |>
      ggplot(aes(MonthName, City, fill = Peak)) + geom_tile(colour = "white") +
      scale_fill_gradient(low = "#E9EDF2", high = RED, labels = percent, name = "Peak share") +
      labs(title = "Peak-Demand Share by City and Month", x = NULL, y = NULL) + theme_dash()
  })
  output$p_peakapp <- renderPlot({
    guard(fd())
    fd() |> select(PeakDemand, Fan, Refrigerator, AirConditioner, Television, Monitor) |>
      pivot_longer(-PeakDemand, names_to = "Appliance", values_to = "Level") |>
      group_by(Appliance, Group = ifelse(PeakDemand == 1, "Peak", "Non-peak")) |>
      summarise(Mean = mean(Level), .groups = "drop") |>
      ggplot(aes(Appliance, Mean, fill = Group)) + geom_col(position = "dodge", width = 0.7) +
      scale_fill_manual(values = c(Peak = RED, `Non-peak` = NAVY), name = NULL) + coord_flip() +
      labs(title = "Mean Appliance Level: Peak versus Non-peak", x = NULL, y = "Mean usage level") + theme_dash()
  })

  newhh <- reactive({
    m <- match(input$p_month, month.abb)
    data.frame(Fan = input$p_fan, Refrigerator = input$p_ref, AirConditioner = input$p_ac,
               Television = input$p_tv, Monitor = input$p_mon, DaysInMonth = days[m],
               City = factor(input$p_city, levels = levels(df$City)))
  })
  pred_hours <- reactive(as.numeric(predict(m_lm, newhh())))
  pred_prob  <- reactive(as.numeric(predict(m_glm, newhh(), type = "response")))
  output$o_hours <- renderUI(kpi(round(pred_hours()), "Predicted monthly hours"))
  output$o_prob  <- renderUI(kpi(percent(pred_prob(), accuracy = 0.1), "Probability of peak demand"))
  output$o_bill  <- renderUI({
    tr <- tariff_by_city$Tariff[tariff_by_city$City == input$p_city]
    kpi(paste0("INR ", comma(round(pred_hours() * tr))), "Estimated monthly bill")
  })
  output$p_contrib <- renderPlot({
    nh <- newhh(); mu <- df |> summarise(across(c(Fan, Refrigerator, AirConditioner, Television, Monitor), mean))
    b  <- coef(m_lm)[c("Fan", "Refrigerator", "AirConditioner", "Television", "Monitor")]
    tibble(Appliance = names(b), Effect = as.numeric(b) * (as.numeric(nh[names(b)]) - as.numeric(mu[names(b)]))) |>
      ggplot(aes(reorder(Appliance, Effect), Effect, fill = Effect >= 0)) + geom_col(width = 0.7, show.legend = FALSE) +
      scale_fill_manual(values = c(`TRUE` = RED, `FALSE` = BLUE)) + coord_flip() +
      labs(title = "Contribution to Predicted Consumption Relative to the Average Household",
           x = NULL, y = "Hours above or below average") + theme_dash()
  })
  output$tbl <- renderDT({
    datatable(fd() |> select(City, Company, MonthName, Fan, Refrigerator, AirConditioner, Television, Monitor,
                             MonthlyHours, TariffRate, ElectricityBill, PeakDemand),
              rownames = FALSE, filter = "top", options = list(pageLength = 15, scrollX = TRUE))
  })
}

shinyApp(ui, server)
