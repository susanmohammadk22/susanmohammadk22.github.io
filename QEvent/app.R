library(shiny)
library(DBI)
library(RPostgres)

# UI
ui <- fluidPage(
  titlePanel("Question Submission System"),
  
  tabsetPanel(
    tabPanel("Submit Question",
             textAreaInput("question", "Type your question:", rows = 5),
             selectInput("country", "Country question is about:",
                         choices = c("USA", "China", "Russia", "UK", "Iran", "Other")),
             actionButton("submit", "Submit"),
             verbatimTextOutput("result")
    ),
    
    tabPanel("Speaker Dashboard",
             tableOutput("questions"),
             actionButton("select", "Select"),
             actionButton("reject", "Reject")
    ),
    
    tabPanel("Live Display",
             h3("Current Question"),
             textOutput("current_q"),
             h3("Live Answer"),
             textOutput("live_answer")
    )
  )
)

# Server
server <- function(input, output, session) {
  
  output$result <- renderPrint({
    if(input$submit > 0) {
      cat("Question submitted!\n")
      cat("Question:", input$question, "\n")
      cat("Country:", input$country)
    }
  })
  
  output$questions <- renderTable({
    data.frame(
      ID = 1:3,
      Question = c("Sample Q1", "Sample Q2", "Sample Q3"),
      Status = "Pending"
    )
  })
  
  output$current_q <- renderText({
    "Sample question for demo"
  })
  
  output$live_answer <- renderText({
    "Sample answer for demo"
  })
}

# Run
shinyApp(ui, server)